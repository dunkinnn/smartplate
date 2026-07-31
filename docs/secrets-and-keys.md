# Secrets and Keys

Where every credential lives, and why. Anything compiled into the Flutter app
can be extracted from the APK with standard tooling, so the dividing line is
simple: if leaking it would be bad, it never ships in the app.

## Three categories

### 1. Safe in the app

| Value | Where | Why it is safe |
| --- | --- | --- |
| Supabase project URL | `lib/main.dart` | Appears in every request anyway |
| Supabase anon / publishable key | `lib/main.dart` | A JWT with `role: anon`. Grants nothing by itself; RLS and table grants decide what it can reach |

These are public by design. Rotating them is not a security fix.

**What actually protects the data:** RLS policies (`auth.uid() = user_id`) plus
table grants. If those are wrong, the anon key becomes dangerous. If they are
right, publishing the key changes nothing.

### 2. Server-only, never in the app

| Value | Where it lives | Used by |
| --- | --- | --- |
| Supabase `service_role` key | Supabase secrets only | Never needed by this app |
| Model API key (`GEMINI_API_KEY`) | Supabase secrets | `generate-meal-plan` Edge Function |
| SMTP password / email API key | Supabase Auth settings or Edge Function secrets | Transactional email |

Set with:

```
supabase secrets set GEMINI_API_KEY=...
```

Read inside a function with `Deno.env.get('GEMINI_API_KEY')`. The value is never
returned to the client and never appears in the repo.

The `service_role` key deserves specific mention: it **bypasses RLS entirely**.
It belongs in server-side code only, and this app has no reason to use it at
all. If it ever appears in `lib/`, treat it as a full data breach and rotate it.

### 3. User secrets

Passwords are never stored by the app. Supabase Auth hashes them with bcrypt in
`auth.users.encrypted_password`. The app only ever sends a password over TLS
during sign-up and sign-in.

## Email, when you add it

Two options, both keeping credentials off the device:

**Supabase Auth SMTP** (for confirmations, password resets). Dashboard →
Project Settings → Authentication → SMTP Settings. Credentials are stored by
Supabase; the app sends nothing but the request to `auth.signUp()`.

**An email API via Edge Function** (for anything custom, e.g. weekly summaries).
Same shape as the meal plan function:

```
supabase secrets set RESEND_API_KEY=...
```

The app calls `functions.invoke('send-summary')`; the function holds the key.
Never call an email provider's API directly from Flutter, for the same reason as
the model API: the key would ship in the APK.

## Adding a new provider

1. Get the key from the provider.
2. `supabase secrets set PROVIDER_KEY=...`
3. Read it in the Edge Function with `Deno.env.get`.
4. The app calls the function, never the provider.

If a task seems to need a key in the app, that is the signal to move the call
into a function instead.

## Repository hygiene

- No `.env` file is committed. If one is added, list it in `.gitignore` first.
- Never paste a key into a chat, an issue, a commit message, or a screenshot.
- Never `console.log` or `debugPrint` a key, including while debugging. Logs
  outlive the debugging session.
- Before a first public push, scan history: a key removed in a later commit is
  still readable in the earlier one.

## If a key leaks

1. Create a replacement at the provider.
2. `supabase secrets set` the new value and redeploy the function.
3. Delete or disable the old key only after the new one is confirmed working.
4. Check the provider's usage logs for calls you did not make.

Order matters: deleting first causes downtime, and panic makes step 4 get
skipped.

## Restrictions worth applying

- **Gemini key:** restrict it to the Generative Language API in AI Studio.
  Unrestricted keys are rejected by the API and are the ones automated scanners
  hunt for in public repos.
- **Billing alerts:** set one in Google Cloud Console. A leaked key or a
  runaway retry loop shows up as spend before it shows up anywhere else.
- **Rate limiting:** the regenerate button has no cap. Add a per-user daily
  limit inside the Edge Function before real users touch it.
