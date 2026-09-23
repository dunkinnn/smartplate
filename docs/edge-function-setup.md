# Edge Function Setup

Steps to deploy `generate-meal-plan`. Run from the project root.

## 1. Get an OpenAI API key

Buy prepaid credits at [platform.openai.com](https://platform.openai.com)
(Settings, Billing) with auto-reload off, then create a secret key under
Settings, API keys. Copy it once; it is not shown again.

## 2. Install the Supabase CLI

```
npm install -g supabase
supabase login
```

## 3. Link the project

Find the project ref in your Supabase dashboard URL
(`https://supabase.com/dashboard/project/<ref>`).

```
supabase link --project-ref <ref>
```

## 4. Store the key as a secret

Never put this in the repo, in the Flutter app, or in a committed `.env`.

```
supabase secrets set OPENAI_API_KEY=your_key_here
```

## 5. Deploy

```
supabase functions deploy generate-meal-plan
```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are injected automatically, so only the
model key needs setting.

## 6. Check the logs when something fails

Open the function's Logs tab in the dashboard:

```
https://supabase.com/dashboard/project/<ref>/functions/generate-meal-plan/logs
```

Older CLI versions have no `functions logs` subcommand, so the dashboard is the
reliable route.

## Notes

- The function derives the user from the JWT the app sends. A `user_id` in the
  request body is ignored by design.
- Allergens are re-checked in code after the model responds. If a dish or
  ingredient matches an allergen, the plan is rejected and regenerated once
  before the request fails.
- The model defaults to `gpt-6-luna`. Switch without redeploying with
  `supabase secrets set OPENAI_MODEL=gpt-6-sol`.
- Each user gets 2 generations per Manila calendar day, counted in `ai_usage`.
  A plan with `saved_at` set cannot be regenerated.
  Run `supabase/ai-usage-table.sql` in the SQL editor before deploying.
- Swapping providers means editing `OPENAI_URL`, `callOpenAI`, and the secret
  name in `index.ts`. Nothing else in the app depends on the provider.
