// Generates a day's meal plan for the signed-in user and saves it.
// Deploy: supabase functions deploy generate-meal-plan
// Secret:  supabase secrets set GEMINI_API_KEY=...

import { createClient } from 'jsr:@supabase/supabase-js@2';

// Override without redeploying: supabase secrets set GEMINI_MODEL=...
// Must be a current stable model. Retired models return 429 with no quota,
// and preview models usually require billing to be enabled.
const MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.5-flash-lite';
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

// Provider rejected the request outright, so retrying will not help.
class ModelUnavailable extends Error {}

const MEAL_TYPES = ['Breakfast', 'Lunch', 'Dinner'];

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Splits a free-text allergen field into comparable tokens.
function parseAllergens(raw: unknown): string[] {
  if (typeof raw !== 'string' || !raw.trim()) return [];
  return raw
    .toLowerCase()
    .split(/[,;/]+|\band\b/)
    .map((s) => s.trim())
    .filter((s) => s.length > 2 && s !== 'none');
}

// Rejects a plan if an allergen appears in any dish name or ingredient.
// Enforced here rather than trusting the prompt, because a model ignoring
// this constraint is a safety problem, not a quality one.
function findAllergenViolation(
  meals: PlanMeal[],
  allergens: string[],
): string | null {
  if (allergens.length === 0) return null;

  for (const meal of meals) {
    const haystack = [
      meal.name,
      ...(meal.ingredients ?? []).map((i) => i.name),
    ]
      .join(' ')
      .toLowerCase();

    for (const allergen of allergens) {
      if (haystack.includes(allergen)) {
        return `${meal.name} contains ${allergen}`;
      }
    }
  }
  return null;
}

interface Ingredient {
  name: string;
  quantity: string;
  category: string;
}

interface PlanMeal {
  meal_type: string;
  name: string;
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  ingredients: Ingredient[];
}

function buildPrompt(profile: Record<string, unknown>, recent: string[]) {
  const target = Number(profile.calorie_target) || 2000;

  return `You are a nutritionist creating a one-day meal plan.

Person:
- Age: ${profile.age ?? 'unknown'}, gender: ${profile.gender ?? 'unknown'}
- Height: ${profile.height_cm ?? 'unknown'} cm, weight: ${profile.weight_kg ?? 'unknown'} kg
- Activity level: ${profile.activity_level ?? 'unknown'}
- Goal: ${profile.weight_goal ?? 'maintain'}
- Daily calorie target: ${target} kcal
- Macro targets: protein ${profile.protein_goal_g ?? '?'} g, carbs ${profile.carbs_goal_g ?? '?'} g, fat ${profile.fat_goal_g ?? '?'} g
- Diet: ${profile.diet ?? 'no restriction'}
- Taste preference: ${profile.taste ?? 'no preference'}
- ALLERGIES (must never appear, including as an ingredient): ${profile.allergen ?? 'none'}
- Foods to avoid: ${profile.food_restriction ?? 'none'}

${recent.length ? `Do not repeat these recent dishes: ${recent.join(', ')}.` : ''}

Rules:
- Exactly one dish for each of Breakfast, Lunch, Dinner.
- Total calories within 10 percent of ${target}.
- Use common, affordable ingredients suited to Filipino home cooking.
- Ingredient category must be one of: Protein, Vegetables, Fruits, Grains, Dairy, Pantry.

Reply with JSON only, no markdown fence, matching exactly:
{"meals":[{"meal_type":"Breakfast","name":"...","kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"ingredients":[{"name":"...","quantity":"100 g","category":"Protein"}]}]}`;
}

async function callGemini(apiKey: string, prompt: string): Promise<PlanMeal[]> {
  const res = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.9,
        responseMimeType: 'application/json',
      },
    }),
  });

  if (!res.ok) {
    // Google explains the cause in the body; without it a bare 429 is
    // indistinguishable from "no free quota for this model".
    const body = await res.text();
    console.error(`Gemini ${res.status} for model ${MODEL}: ${body}`);

    const detail = body.slice(0, 300);
    if (res.status === 429) {
      throw new ModelUnavailable(
        `Quota exceeded for ${MODEL}. ${detail}`,
      );
    }
    throw new ModelUnavailable(`Model request failed (${res.status}). ${detail}`);
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('Empty model response');

  const parsed = JSON.parse(text);
  const meals = parsed?.meals;
  if (!Array.isArray(meals)) throw new Error('Response missing meals array');

  return meals;
}

// Rejects anything that would violate the table constraints downstream.
function validate(meals: PlanMeal[]): string | null {
  if (meals.length < 3) return 'Plan has fewer than three meals';

  for (const meal of meals) {
    if (!MEAL_TYPES.includes(meal.meal_type)) {
      return `Unexpected meal type: ${meal.meal_type}`;
    }
    if (!meal.name || typeof meal.name !== 'string') {
      return 'A meal is missing its name';
    }
    if (!Number.isFinite(meal.kcal) || meal.kcal < 0) {
      return `Invalid calories for ${meal.name}`;
    }
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) return json({ error: 'Model API key not configured' }, 500);

  // The caller's JWT decides whose plan this is. Never trust a user_id
  // supplied in the request body.
  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData } = await supabase.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: 'Not signed in' }, 401);

  let planDate: string;
  try {
    const body = await req.json();
    planDate = body?.plan_date ?? new Date().toISOString().slice(0, 10);
  } catch {
    planDate = new Date().toISOString().slice(0, 10);
  }

  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select(
      'age, gender, height_cm, weight_kg, activity_level, weight_goal, calorie_target, protein_goal_g, carbs_goal_g, fat_goal_g, diet, taste, allergen, food_restriction',
    )
    .eq('id', user.id)
    .maybeSingle();

  if (profileError) return json({ error: profileError.message }, 500);
  if (!profile) return json({ error: 'Complete your profile first' }, 400);

  // Recent dish names, so the model does not repeat itself all week.
  const { data: recentItems } = await supabase
    .from('meal_plan_items')
    .select('name, meal_plans!inner(user_id, plan_date)')
    .eq('meal_plans.user_id', user.id)
    .order('plan_date', { referencedTable: 'meal_plans', ascending: false })
    .limit(15);

  const recentNames = (recentItems ?? []).map((r: { name: string }) => r.name);
  const allergens = parseAllergens(profile.allergen);
  const prompt = buildPrompt(profile, recentNames);

  // One retry: models occasionally return malformed JSON or ignore a rule.
  let meals: PlanMeal[] | null = null;
  let lastError = '';

  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const candidate = await callGemini(apiKey, prompt);
      const invalid = validate(candidate);
      if (invalid) {
        lastError = invalid;
        continue;
      }
      const violation = findAllergenViolation(candidate, allergens);
      if (violation) {
        lastError = `Allergen check failed: ${violation}`;
        continue;
      }
      meals = candidate;
      break;
    } catch (e) {
      lastError = e instanceof Error ? e.message : String(e);
      // Quota and auth failures will not fix themselves on a second call.
      if (e instanceof ModelUnavailable) break;
    }
  }

  if (!meals) {
    return json({ error: `Could not generate a plan. ${lastError}` }, 502);
  }

  const totalKcal = meals.reduce((sum, m) => sum + Math.round(m.kcal), 0);

  // Replace any existing plan for this date.
  const { data: plan, error: planError } = await supabase
    .from('meal_plans')
    .upsert(
      {
        user_id: user.id,
        plan_date: planDate,
        total_kcal: totalKcal,
        model: MODEL,
        generated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,plan_date' },
    )
    .select('id')
    .single();

  if (planError) return json({ error: planError.message }, 500);

  await supabase.from('meal_plan_items').delete().eq('plan_id', plan.id);

  const { error: itemsError } = await supabase.from('meal_plan_items').insert(
    meals.map((meal, i) => ({
      plan_id: plan.id,
      meal_type: meal.meal_type,
      name: meal.name,
      kcal: Math.round(meal.kcal),
      protein_g: meal.protein_g ?? 0,
      carbs_g: meal.carbs_g ?? 0,
      fat_g: meal.fat_g ?? 0,
      ingredients: meal.ingredients ?? [],
      sort_order: MEAL_TYPES.indexOf(meal.meal_type) >= 0
        ? MEAL_TYPES.indexOf(meal.meal_type)
        : i,
    })),
  );

  if (itemsError) return json({ error: itemsError.message }, 500);

  return json({ plan_id: plan.id, plan_date: planDate, total_kcal: totalKcal });
});
