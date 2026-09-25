-- Nutrition focus picked in sign-up and Settings, e.g. "High Protein, Low Sugar".
-- Taste, allergen and food_restriction keep their text type and now hold comma-separated choices.

alter table public.user_profiles
  add column if not exists nutrition_focus text;

notify pgrst, 'reload schema';

-- Verify.
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'user_profiles'
  and column_name in ('taste', 'allergen', 'food_restriction', 'nutrition_focus');
