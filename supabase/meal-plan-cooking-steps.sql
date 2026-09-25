-- Cooking guide per planned dish: short steps and total cooking time.

alter table public.meal_plan_items
  add column if not exists steps jsonb default '[]'::jsonb,
  add column if not exists cook_minutes integer default 0;

notify pgrst, 'reload schema';

-- Verify: expect 2 rows.
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'meal_plan_items'
  and column_name in ('steps', 'cook_minutes');
