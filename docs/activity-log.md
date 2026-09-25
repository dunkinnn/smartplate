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

## 2026-09-23 - Animated launch screen

- New `screens/splash.dart`: logo scales and fades in, "Smart Plate" and the tagline rise in one after another (about 1.4s), then fades into Home or Login.
- `main.dart`: `home` is `SplashScreen(next: ...)`, keeping the signed-in check.
- Not committed.

## 2026-09-23 - Home meal order

- `dashboard.dart`: Today's Meal Plan on Home is sorted Breakfast, Lunch, Dinner, Snack in the app, not only by `sort_order`.
- Not committed.

## 2026-09-23 - Phone notifications (Calorie and Nutrient Alert System)

- Dependencies to add: `flutter_local_notifications`, `timezone` (via `flutter pub add`).
- New `services/alert_service.dart`: meal reminders at 10:00, 14:00, 21:00 Manila time for today (unlogged meals only) and the next two days; instant alerts at 90% and 100% of the calorie goal and for protein under 70% of goal after 18:00, each once per day.
- Called on app start (`main.dart`), when Home opens, after marking planned meals eaten, after Log Meal saves, after deleting a food in Track. Logout cancels all reminders.
- Android: core library desugaring in `build.gradle.kts`; POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED permissions and scheduled-notification receivers in `AndroidManifest.xml`.
- Not committed.

## 2026-09-25 - Forgot password fixes

- `otp_verification.dart`: code is verified as `OtpType.email` to match `signInWithOtp` in Forgot Password (was `OtpType.recovery`, which rejects valid codes).
- `forgot_password.dart`: rate-limit errors are checked first (their message also contains "email"); "Signups not allowed for otp" (unknown email with shouldCreateUser: false) now shows "No account found"; only sending/SMTP failures show "Email service error".
- Not committed.

## 2026-09-25 - OTP field digits only

- `otp_verification.dart`: code field uses `FilteringTextInputFormatter.digitsOnly` and a 6-character limit, so letters, spaces and symbols cannot be typed or pasted; submit requires exactly 6 digits.
- Not committed.

## 2026-09-25 - Sample invoice

- Added `docs/sample-email-invoice.pdf`: design sample of an email-service invoice (fictional vendor, SAMPLE watermark, ₱1,150 + ₱150 VAT = ₱1,300) for project documentation.
- Not committed.

## 2026-09-25 - More nutrients, stricter food checks, more options

- New `supabase/extra-nutrients.sql`: `sugar_g`, `fiber_g`, `saturated_fat_g`, `sodium_mg`, `cholesterol_mg` on `meal_plan_items` and `food_logs` (default 0).
- New `models/nutrients.dart` (daily guides: sugar 50 g, fiber 25 g, saturated fat 20 g, sodium 2,000 mg, cholesterol 300 mg) and `widgets/nutrient_guide_row.dart`.
- `food_entry.dart`: new nutrient fields in `fromRow`, `fromPlanItem`, `toRow`.
- Edge Function: schema and insert include the new nutrients; prompt uses multiple tastes and `nutrition_focus`; allergens and avoided foods are checked in code with everyday and Filipino terms (e.g. Dairy catches cheese, Shellfish catches hipon; coconut milk and eggplant are not false matches).
- Meal Plan: dish sheet lists the new nutrients; plan card shows them against daily guides. Track: Nutrients card for the day. Insights: daily averages vs guides and tips when limits are passed.
- Alerts: phone and in-app alerts when sugar, saturated fat, sodium or cholesterol pass the daily guide.
- `preference_chips.dart`: more allergens (Mollusks, Wheat, Corn, Coconut, Mango) and foods to avoid (Red Meat, Organ Meat, Processed Meat, Spicy Food, Instant Noodles, White Rice, MSG).
- Not committed.

## 2026-09-25 - Type your own taste, allergen or avoided food

- `preference_chips.dart`: optional "Add your own" chip opens a small dialog; entries are 2-30 letters (spaces, hyphens, apostrophes allowed), title-cased, up to 5 per list, and saved in the same comma list. Typing a built-in option selects it instead. Typed entries show as selected chips; tapping removes them.
- Enabled for Taste Preferences, Allergens and Foods You Avoid in sign-up (`preferences.dart`) and Settings (`dietary_preferences.dart`). Nutrition focus stays fixed.
- Typed allergens and avoided foods are checked by the Edge Function as literal words, like the built-in ones.
- Not committed.

## 2026-09-25 - Sign-up name not asked twice

- `screens/profile.dart` (setup step 1): reads `full_name` saved at sign-up from the user's metadata. When present, the Full Name field is hidden and a "Hi, <first name>!" line is shown; the name is still passed on and saved. The field only appears if the name is missing. It stays editable later in Settings → Personal Info.
- Not committed.

## 2026-09-25 - Log out loader

- `client/profile.dart`: Log Out shows a full-screen loader ("Logging out...") that cannot be dismissed while reminders are cleared and the session ends, then goes to Login. On failure the loader closes and a friendly message is shown. Double taps are ignored.
- Not committed.

## 2026-09-25 - Allergy note on Meal Plan

- `meal_plan.dart`: an orange info note ("Always check ingredients and labels if you have a severe allergy...") appears under the meal plan and in each dish's details sheet.
- Not committed.

## 2026-09-25 - White launch screen, no system logo

- `values-night/styles.xml`: launch and normal themes use the light parent, so dark mode no longer shows a black screen at launch.
- `drawable-v21/launch_background.xml`: plain white background.
- New `values-v31/styles.xml`, `values-night-v31/styles.xml` and `drawable/splash_transparent.xml`: Android 12+ system splash is white with an empty icon, so only the animated Flutter intro shows the logo.
- Not committed.

## 2026-09-25 - Cleaner Meal Plan layout

- `meal_plan.dart` (calendar and legend unchanged): Planned Total, the "3 meals / AI generated" chips and the macro card merged into one summary card with a goal pill and three compact macro stats; sugar, fiber and the other nutrients fold under "See all nutrients".
- A single "MEALS / Tap a dish for details" header replaces the hint repeated in every card.
- Meal cards use the Home meal icon tile (`MealBadge`), meal total on the right and one row per dish with a chevron, instead of the tinted side strip.
- Not committed.

## 2026-09-25 - Cleaner Track layout

- `track.dart` (calendar unchanged): calorie card keeps the ring and Remaining, with the status and streak pills in one row and a new bottom strip "N of M planned meals eaten" with one segment per meal.
- Nutrients card: protein, carbs and fat against profile goals; sugar, fiber and the rest fold under "See all nutrients".
- Meal cards: planned dish in a soft row with a clear "Ate" button (becomes a green "Eaten" button; past days show Eaten/Not eaten, future days Planned). Hand-logged foods listed below with delete; the full-width "Log Item" button is now a small "Add food" link. Section header renamed "MEALS".
- Not committed.

## 2026-09-25 - Plan confirmation screen

- New `client/plan_confirmed.dart`: full-screen confirmation after "Use this plan" (animated check, "Plan confirmed!", meal count and calories, each meal with its icon, "Go to Track" and "Back to Meal Plan").
- `meal_plan.dart`: the in-page "Plan confirmed" card is removed; confirmed plans show no action buttons. New optional `onOpenTrack`, passed from `dashboard.dart`.
- `track.dart`: lint fix, null-aware element `?planned`.
- Not committed.

## 2026-09-25 - Cleaner Insights layout

- `insight.dart` (date chip and streak row unchanged): the ring card becomes a summary card like Meal Plan (average kcal, status pill, progress bar, "Goal X kcal · N of M days logged").
- Cards share one style: small uppercase grey titles, 20px padding and radius.
- Weekly trend: slimmer bars on a shared baseline with a goal line.
- Nutrients: protein, carbs and fat as compact stats against goals; sugar, fiber and the rest fold under "See all nutrients".
- Smart Advice: tips use a lightbulb icon instead of bullets. Unused `_buildMiniStat` and `_buildNutrientRow` removed.
- Not committed.

## 2026-09-25 - Cleaner Grocery and Profile

- `grocery.dart`: header card matches the other summaries ("SHOPPING LIST", date, "N meals · M items", "X left" pill, progress bar). Each meal is one card with compact rows (round check, name and amount, small category icon) instead of a separate card per item. Unused `_dayCount` removed.
- `client/profile.dart`: header card with a green-ringed photo, name and email, plus Daily goal, Diet and Streak. Option icons use the green tinted tile; chevron trailing icon; section headers aligned with the cards.
- Not committed.

## 2026-09-25 - Cleaner Log Nutrition screen

- `log_meal.dart` (calendar unchanged): sections labelled MEAL, ADD FOOD, YOUR PLATE in the shared small uppercase style.
- Meal type: four equal chips with the Home meal icons; selected chip is green tinted with a green border.
- Search field is flat grey with a light border; saved-food suggestions are rounded white pills.
- One "plate" card holds the meal header and total, each staged food (with a remove button), an "Add custom food" link and protein/carbs/fat totals, replacing the separate empty state, food cards, custom button and macro card.
- Save button reads "Save to Track".
- Not committed.

## 2026-09-25 - Log Nutrition calendar matches Track

- `log_meal.dart`: calendar uses `visibleDays()` (signup-based week), equal-width days, "Today" label and the same card style as Track. Only today can be selected; other days are shown faded, since food is logged for today only.
- Not committed.

## 2026-09-25 - Future days not tappable

- `meal_plan.dart`, `track.dart`: calendar days after today are faded and cannot be tapped; today and past days work as before.
- Not committed.

## 2026-09-25 - Profile header overflow

- `client/profile.dart`: streak pill in the header facts row wrapped in `FittedBox(scaleDown)`, fixing a 2.6 px right overflow on narrow screens.
- Not committed.

## 2026-09-25 - Cooking steps in Meal Plan

- New `supabase/meal-plan-cooking-steps.sql`: `meal_plan_items.steps` (jsonb list) and `cook_minutes`.
- Edge Function: AI returns 3-6 home-cook steps and total cooking time per dish (schema-enforced); stored capped at 8 steps of 300 characters and 0-240 minutes. Steps are included in the allergen and avoided-food check.
- `meal_plan.dart`: dish sheet shows "HOW TO COOK" numbered steps with the cooking time; meal cards show the time next to each dish; header hint reads "Tap a dish for recipe". Older plans without steps show a note to regenerate.
- Not committed.

## 2026-09-25 - Plans appear only after "Use this plan"

- `track.dart`, `grocery.dart`, `dashboard.dart`: meal plan queries add `saved_at is not null`, so Track's planned meals, the Grocery list and Home's Today's Meal Plan only show a plan once it is confirmed. Draft plans stay on Meal Plan only.
- Empty-state text on Grocery and Home tells users to tap "Use this plan".
- Not committed.

## 2026-09-25 - Terms and Privacy Policy screens

- New `screens/legal.dart`: the Terms and Privacy text (unchanged wording, moved from `signup.dart`) and a full-screen `LegalScreen`: header card with icon, title, effective date and intro; numbered sections; "Questions?" contact card; sticky "Accept" button.
- `signup.dart`: the links open `LegalScreen` instead of a plain dialog; tapping Accept ticks the agreement checkbox.
- Not committed.

## 2026-09-25 - Offline banner and release internet permission

- New `widgets/connection_banner.dart`: wraps the app (in `main.dart` builder) and shows a red "No internet connection. Check your Wi-Fi or mobile data." banner with Retry at the top of every screen while offline. Checks by resolving supabase.co every 15 s (every 4 s while offline) and when the app resumes.
- `android/app/src/main/AndroidManifest.xml`: added the INTERNET permission. It was only in the debug and profile manifests, so release APKs could not reach Supabase or OpenAI.
- Not committed.
