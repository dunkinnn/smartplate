# AI Features Plan

Design for the AI-driven parts of Smart Plate: meal plan generation, grocery
list, tracking assistance, and AI Smart Advice in Insights.

Status: proposal. Nothing here is built yet.

## Current state

All four client screens are static UI with hardcoded values:

| Screen | File | Hardcoded content |
| --- | --- | --- |
| Meal Plan | `client/meal_plan.dart` | 3 meal cards, fixed calendar dates 23-29 |
| Grocery | `client/grocery.dart` | 3 `GroceryItem` entries in a local list |
| Track | `client/track.dart` | 3 meal cards with fixed foods and kcal |
| Insights | `client/insight.dart` | Weekly bars, nutrient rows, 2 advice bullets |
| Log Meal | `client/log_meal.dart` | Food rows, totals |

Real data that already exists in `user_profiles`: `full_name`, `age`, `gender`,
`height_cm`, `weight_kg`, `diet`, `taste`, `allergen`, `food_restriction`,
`calorie_target`, `weight_goal`, `target_weight`, `activity_level`,
`protein_goal_g`, `carbs_goal_g`, `fat_goal_g`, `avatar_url`.

Nothing records what the user actually ate. That gap blocks Track and Insights.

## Architecture

The Flutter app never talks to a model provider directly. An API key shipped in
an APK can be extracted, so the key lives only in Supabase secrets.

```
Flutter app
   |  supabase.functions.invoke('generate-meal-plan')
   v
Supabase Edge Function  (Deno)
   |  reads user_profiles via service role
   |  builds prompt, calls model API with key from Deno.env
   |  validates JSON response
   v
Postgres  (writes meal_plans / meal_plan_items)
   |
   v
Flutter app reads the saved rows through normal RLS-protected selects
```

Consequences of this shape:

- The function authenticates the caller from the JWT Supabase passes through,
  so a user can only generate plans for themselves.
- Generated output is persisted, not streamed to the UI and discarded. Screens
  read from Postgres, so they work offline-ish and cost nothing to re-open.
- Model calls happen on generate, not on every screen view. This is the main
  cost control.

## Required tables

None of these exist yet. All need RLS with `auth.uid() = user_id`.

### meal_plans
One row per user per day.

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| user_id | uuid | fk auth.users, cascade delete |
| plan_date | date | unique with user_id |
| total_kcal | int | sum of items, denormalized for the header |
| generated_at | timestamptz | |
| model | text | which model produced it, for debugging |

### meal_plan_items
Individual dishes within a plan.

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| plan_id | uuid | fk meal_plans, cascade delete |
| meal_type | text | Breakfast / Lunch / Dinner / Snack |
| name | text | |
| kcal | int | |
| protein_g, carbs_g, fat_g | numeric | |
| ingredients | jsonb | `[{name, quantity, unit, category}]`, feeds the grocery list |
| sort_order | int | |

### food_logs
What the user actually ate. Written by Log Meal, read by Track, Insights, and
the dashboard's consumed-calories figure.

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| user_id | uuid | fk auth.users, cascade delete |
| logged_date | date | index with user_id |
| meal_type | text | |
| name | text | |
| quantity | text | free text, e.g. "50g" |
| kcal | int | |
| protein_g, carbs_g, fat_g | numeric | |
| source | text | `plan` / `custom` / `search` |

### grocery_items
Derived from a plan, but editable, so it needs its own table rather than being
recomputed on every open.

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| user_id | uuid | fk auth.users, cascade delete |
| plan_id | uuid | nullable, null when hand-added |
| name, quantity, category | text | |
| is_checked | bool | default false |

### ai_advice
Cached advice so Insights does not call the model on every open.

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| user_id | uuid | fk auth.users, cascade delete |
| period_start, period_end | date | the week the advice covers |
| bullets | jsonb | `["...", "..."]` |
| generated_at | timestamptz | |

## The four features

### 1. Meal Plan generation
**Function:** `generate-meal-plan`
**Input:** target date, optionally a "regenerate" flag.
**Model sees:** age, gender, height, weight, activity level, calorie target,
macro goals, diet, taste preference, allergens, food restrictions. Plus the last
7 days of plans so it does not repeat dishes.
**Output contract:** strict JSON, meals with name, kcal, macros, ingredients.
Validate against a schema before writing; reject and retry once on malformed
output rather than storing garbage.
**Guardrails:** total kcal within +/-10% of `calorie_target`; hard-reject any
plan containing a listed allergen, in code, not just in the prompt. An allergen
slipping through is a safety issue, not a quality issue.

### 2. Grocery list
No model call needed. Aggregate `ingredients` across the selected plan range,
sum quantities by name and unit, group by category. Write to `grocery_items`.
A model call is only worth it later for unit normalization ("2 cups" vs "480ml").

### 3. Track
Mostly not AI. The screen reads `food_logs` and compares against goals.
The AI part is in Log Meal: given a free-text entry like "chicken adobo, 1 cup",
estimate kcal and macros. Function `estimate-nutrition`, returns a single JSON
object. Always show the estimate as editable before saving, and mark the row
`source = 'custom'` so estimates are distinguishable from known values.

### 4. AI Smart Advice
**Function:** `generate-advice`
**Input:** last 7 days of `food_logs` aggregated to daily totals, plus goals.
Send aggregates, never raw meal-by-meal history, to keep the prompt small.
**Output:** 2-3 short bullets, which is what the existing card renders.
**Cadence:** once per week per user, cached in `ai_advice`. Regenerate only when
the cached row is older than the current week.
**Tone constraint:** the prompt must forbid medical claims and prescriptive
diagnosis. This is a nutrition-adjacent app used by minors potentially, so
advice stays descriptive ("protein was lower than your goal") rather than
directive about health outcomes.

## Build order

Each step is usable on its own and unblocks the next.

1. **`food_logs` table + Log Meal writes to it.** No AI. Immediately makes Track
   and the dashboard's consumed-calories real. Highest value per effort.
2. **`meal_plans` + `meal_plan_items` + `generate-meal-plan`.** The first real
   AI feature, and the one the app is named for.
3. **Grocery list derived from plans.** Pure aggregation, no model call.
4. **`estimate-nutrition` for custom foods.** Small, self-contained.
5. **`ai_advice` + `generate-advice`.** Last, because it needs several weeks of
   logs before the output is worth reading.

## Open questions

- **Model provider.** Affects the Edge Function's HTTP call and the JSON mode
  available. Needs deciding before step 2.
- **Cost ceiling.** Meal plan generation per user per day is the main spend.
  Consider generating a week at a time instead of a day.
- **Offline behavior.** Plans are cached in Postgres but still need network.
  Decide whether to cache the current day locally via `shared_preferences`.
- **Regeneration limits.** Without a cap, a user can spam regenerate. Suggest a
  daily limit enforced in the function.

## Security notes

- Model API key in Supabase secrets, read via `Deno.env.get`. Never in the repo,
  never in the Flutter app, never in a committed `.env`.
- Edge Functions verify the caller's JWT and derive `user_id` from it. Never
  accept a `user_id` from the request body.
- Do not send `full_name`, email, or `avatar_url` to the model. The prompt needs
  age, weight, goals and preferences; it does not need identity.
- Log model requests without the user identifier if logging at all.
