# Activity Log

## 2026-09-23 - Switch meal plan AI from Gemini to OpenAI

- `generate-meal-plan/index.ts`: calls the OpenAI Responses API with `gpt-6-luna`, low reasoning, `store: false`, and a strict JSON schema.
- Added a fixed Smart Plate persona (`INSTRUCTIONS`): Filipino home cooking, no allergens, no medical claims, profile text treated as data only.
- Added the missing +/-10 percent calorie check in `validate()`.
- Added a daily cap of 3 generations per user per Manila day, logged in the new `ai_usage` table (`supabase/ai-usage-table.sql`).
- Provider error details now go to function logs only, not to the user.
- `meal_plan.dart`: shows the function's error message (for example the daily limit) instead of the raw `FunctionException` text.
- Docs updated: `edge-function-setup.md`, `secrets-and-keys.md`, `ai-features-plan.md`.
- Secrets needed: `OPENAI_API_KEY`; optional `OPENAI_MODEL` override. `GEMINI_API_KEY` can be removed after testing.
- Not committed.

## 2026-09-23 - Fix stale grocery list after Regenerate

- `generate-meal-plan/index.ts`: deletes the plan's `grocery_items` when a plan is regenerated, so Grocery rebuilds from the new meals. Uses the existing delete RLS policy.
- Not committed.

## 2026-09-23 - Log planned meals from Meal Plan

- `meal_plan.dart`: each meal card has a Log / Logged toggle. Logging inserts the meal's dishes into `food_logs` with `source = 'plan'`; tapping again removes them.
- Logged state is loaded per selected day from `food_logs`.
- `supabase/food-logs-delete-policy.sql`: delete policy on `food_logs`, required for un-logging.
- Not committed.

## 2026-09-23 - Save plan, 2 generations per day, fresh tabs

- `generate-meal-plan/index.ts`: daily limit lowered to 2; refuses to regenerate a plan with `saved_at` set (409).
- `supabase/meal-plans-saved-column.sql`: adds `meal_plans.saved_at`.
- `meal_plan.dart`: Save button beside Regenerate logs every unlogged meal to `food_logs`, sets `saved_at`, then shows a saved banner instead of the buttons.
- `dashboard.dart`: Grocery, Track and Insights are rebuilt when their tab is selected, so they show meals logged or regenerated on other tabs.
- Not committed.

## 2026-09-23 - Daily limit switchable for testing

- `generate-meal-plan/index.ts`: `DAILY_LIMIT` now reads the `DAILY_LIMIT` secret (default 2); `0` turns the cap off. Usage is still logged in `ai_usage`.
- Not committed.

## 2026-09-23 - Track connected to Meal Plan

- `food_entry.dart`: `FoodEntry.fromPlanItem` builds a one-serving `source = 'plan'` entry; Meal Plan and Track both use it, replacing the local `_logRow`.
- `track.dart`: loads the day's plan; each meal card shows the planned dish with a tap-if-eaten check that logs or removes the same `food_logs` rows as Meal Plan's Log button. Hand-logged foods list below it.
- `track.dart`: calorie card adds "Plan X kcal, N of M meals eaten".
- Not committed.

## 2026-09-23 - UX restructure: plan forward, one job per screen

- Meal Plan: calendar shows today and the next 6 days; per-meal Log removed; "Use this plan" only confirms (sets `saved_at`) and points to Track. Title "Meal Plan".
- Edge Function: accepts only today to today+6 (Manila) for `plan_date`; default date is Manila today.
- Grocery: one merged list from plans for the next 7 days; checking an item updates every underlying row; Finish Shopping checks off everything left.
- New `services/meal_log_service.dart`: shared "mark planned meal eaten" and "reopen upcoming plans". Track and Home use it.
- Home: today's meals show planned/eaten with a one-tap check.
- Insights: header renamed; placeholder AI text replaced by tips computed from the week's logs ("Smart Advice").
- Tab "Shop" renamed "Grocery". Log Item on Track preselects that card's meal.
- Dietary preferences and nutritional goals: saving reopens upcoming plans and tells the user to regenerate them.
- Not committed.

## 2026-09-23 - Grocery by meal, Track calendar centered on today

- `supabase/grocery-items-meal-type.sql`: adds `grocery_items.meal_type` and clears lists built without it.
- `grocery.dart`: rows are built and merged per meal and ingredient; the screen shows Breakfast, Lunch, Dinner sections with the category icon on each item.
- `track.dart`: calendar shows 3 days back, today, 3 days ahead; future days show the plan but disable the eaten check and Log Item.
- Meal Plan and Track calendars mark today with a dot.
- Not committed.

## 2026-09-23 - Track editable only today, Grocery always by meal

- `track.dart`: only today can be changed. Past days are read-only ("NOT EATEN" / "EATEN"), future days show "PLANNED"; Log Item appears only on today.
- `grocery.dart`: rows without `meal_type` (built before meal grouping) are deleted and rebuilt by meal on load, so the list is always grouped by meal.
- Not committed.

## 2026-09-23 - Meal Plan points to Home for marking meals

- `meal_plan.dart`: confirmed banner says to mark meals as eaten on Home; "Go to Home" shows for today's plan.
- `dashboard.dart`: Meal Plan's back action uses `_selectTab(0)` so Home reloads today's logs and plan.
- Not committed.

## 2026-09-23 - Mark eaten on Meal Plan cards

- `meal_plan.dart`: today's confirmed plan shows an eaten circle on each meal card, using `MealLogService`, so Meal Plan, Home and Track stay in sync. Future days show no circle.
- `dashboard.dart`: Meal Plan also reloads when its tab is selected.
- Not committed.

## 2026-09-23 - Remove eaten circle from Home

- `dashboard.dart`: Today's Meal Plan on Home is display-only again; it keeps the "planned" / "eaten" label. Meals are marked eaten on Meal Plan or Track.
- Not committed.

## 2026-09-23 - Grocery restructure

- `grocery.dart`: header card shows date range, item count and a "X of Y bought" progress bar.
- Each meal section lists items still to buy first, with bought items folded into a "Bought (n)" row and an x/y count.
- Floating "Finish Shopping" button and "All Set!" popup removed. The end of the list has "Mark all as bought (n left)", which becomes a "Shopping done" card with "Start over" (unchecks everything).
- Not committed.

## 2026-09-23 - Grocery date label

- `grocery.dart`: header shows the actual planned days on the list (one date, or first - last) instead of a fixed "Today to +6" range; "Sept" corrected to "Sep"; day count pluralized.
- Not committed.

## 2026-09-23 - Remove hand-logged foods on Track

- `track.dart`: today's hand-logged foods have a delete icon; a confirm dialog removes the `food_logs` row (uses the delete policy from `food-logs-delete-policy.sql`). Planned meals are undone by tapping them instead.
- Not committed.

## 2026-09-23 - Remove eaten circle from Meal Plan

- `meal_plan.dart`: eaten circles removed; Meal Plan only plans and confirms. Banner says to mark meals as eaten in Track. Track is now the single place to record eating; Home shows read-only planned/eaten labels.
- Not committed.

## 2026-09-23 - Meal Plan details, macros, week status

- `meal_plan.dart`: tapping a dish opens a bottom sheet with ingredients, kcal and macros, and an allergy-checked note.
- Summary adds a card with "Fits your X kcal goal" and protein, carbs, fat bars against profile goals.
- Calendar shows "Today" as the label and a dot per day: outlined for a draft plan, filled for a confirmed plan, with a legend.
- `track.dart`: calendar uses the same "Today" label; its today dot is removed.
- Not committed.

## 2026-09-23 - Generate for today only

- Edge Function: `plan_date` must equal today in Manila, otherwise 400 "You can only generate a meal plan for today."
- `meal_plan.dart`: calendar shows the past 6 days and today; Generate, Regenerate and Use this plan appear only on today. Past days show their plan read-only.
- `track.dart`: calendar shows the past 6 days and today.
- `grocery.dart`: list is built from today's plan only.
- Not committed.

## 2026-09-23 - Calendar starts at signup

- New `services/calendar_days.dart`: `visibleDays()` returns up to the past 6 days and today, never before the account's creation date.
- `meal_plan.dart`, `track.dart`: calendars use it; fewer than 7 days are left-aligned with spacing. A new user sees only Today.
- Not committed.

## 2026-09-23 - Calendar weeks start at signup

- `services/calendar_days.dart`: `visibleDays()` returns a 7-day week starting on the signup day (days 1-7, then 8-14, ...), always containing today.
- `meal_plan.dart`: week status loads for that range; future days say "Not planned yet" / "You can generate this plan on that day."
- `track.dart`: same calendar range; future days stay read-only.
- Not committed.

## 2026-09-23 - Insights uses the signup week

- `insight.dart`: week range comes from `visibleDays()` (7 days from signup), same as Meal Plan and Track. Date chip uses "Sep".
- Days Logged and the logging tip count only days up to today ("2 of 3").
- Weekly trend labels today as "Today"; future days show as faint placeholder bars.
- Not committed.

## 2026-09-23 - Home logging streak

- `dashboard.dart`: streak card under the greeting. Streak = consecutive days with at least one `food_logs` row, counted from today (or yesterday while today is not logged yet). Shows the signup-based week as dots (same as other calendars) and a short prompt. Reloads when Home is selected.
- Not committed.

## 2026-09-23 - Home look carried to other tabs

- New `widgets/meal_badge.dart`: `mealStyle`, `MealBadge` (Home's tinted meal icon tile) and `StreakPill`.
- `MealLogService.currentStreak()`: same streak rule as Home.
- Track: meal cards use MealBadge; calorie card shows the streak pill.
- Grocery: meal sections use MealBadge with the meal name as a heading.
- Insights: streak pill beside the week date chip.
- Home unchanged.
- Not committed.

## 2026-09-23 - Login, sign up and onboarding polish

- `main.dart`: opens Dashboard when a Supabase session exists, Login otherwise.
- `login.dart`: "Save Password" removed (it stored the password in plain text); old saved values are cleared on launch. Friendly messages for common auth errors. Keyboard overflow fixed with SafeArea + ConstrainedBox(minHeight). Styled like the app: dark title, grey tagline, filled 16px-radius fields, 55px "Log In" button.
- `signup.dart`: same styling; button reads "Create Account".
- New `widgets/onboarding_progress.dart`: step label, title and 4-part progress bar, used in the app bar of the 4 setup screens.
- Not committed.

## 2026-09-23 - Reverted login, sign up and onboarding polish

- Restored `main.dart`, `login.dart`, `signup.dart` and the 4 onboarding screens to their previous state (Save Password and always-open-Login are back).
- `widgets/onboarding_progress.dart` moved to `_to_delete/` for manual deletion.

## 2026-09-23 - Reverted login, sign up and onboarding polish

- The previous entry was undone: `main.dart`, `login.dart`, `signup.dart` and the four setup screens match the last commit again; `onboarding_progress.dart` is not in the project.
- Not committed.

## 2026-09-23 - Stay signed in, onboarding progress, friendly errors

- `main.dart`: opens Dashboard when a Supabase session exists, Login otherwise.
- New `widgets/onboarding_progress.dart`: "STEP n OF 4", title and a 4-part progress bar, used in the app bar of profile, preferences, nutritional goals and review screens.
- New `services/friendly_error.dart`: `friendlyError(e)` maps auth, database, Edge Function, network and timeout errors to plain messages; database details are never shown.
- Used in login, sign up, forgot password, OTP, update password, review and confirm, Log Meal, Meal Plan, Grocery, Insights, Notifications and the four settings screens.
- Login and sign up styling and Save Password unchanged.
- Not committed.

## 2026-09-23 - Modern bottom navigation bar

- `dashboard.dart`: Material BottomNavigationBar replaced by a floating rounded white bar (16px side margin, 24px radius, border and soft shadow). The active tab becomes a light-green pill with icon and label; inactive tabs show grey icons only. Same five tabs and `_selectTab` behavior; "Shop" label shown as "Grocery".
- Not committed.

## 2026-09-23 - Bottom bar with centre log button

- `dashboard.dart`: floating pill bar replaced by a flat white bar with a thin top border. Order: Home, Meal Plan, Track (raised green + circle in the centre), Grocery, Insights. Tabs show icon and label; active is green. Tab indices unchanged.
- Not committed.

## 2026-09-23 - Nav bar overflow and screen-size fixes

- `dashboard.dart`: nav bar height now comes from its content (no fixed 64px), which fixes the 1px bottom overflow. The Track circle overflows upward via `OverflowBox`; labels scale down to fit.
- `main.dart`: text scale follows the phone setting but is clamped to 0.9-1.2 so large font settings do not break layouts.
- Meal Plan and Track calendars: each day takes an equal share of the width (Expanded) instead of fixed padding, so 7 days fit on narrow phones; day labels scale down.
- Grocery header: date text is Expanded so long ranges wrap. Insights: date chip and streak pill wrap on narrow screens.
- `login.dart`: fixed full-screen height replaced with ConstrainedBox(minHeight) so the keyboard and small screens do not overflow.
- Not committed.

## 2026-09-23 - Notification badge

- `notification.dart`: `unreadNotificationCount()` builds today's notifications with the same rules as the screen and subtracts the ones marked read.
- New `widgets/notification_bell.dart`: bell icon with a red count badge (9+ cap), opens Notifications and refreshes the count on return.
- Bell replaced on Home, Meal Plan, Grocery, Track, Insights, Log Meal and Custom Food headers.
- Not committed.
