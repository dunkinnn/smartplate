-- Marks a plan as confirmed by the user; saved plans cannot be regenerated.

alter table public.meal_plans
  add column if not exists saved_at timestamptz;

-- Verify the column and that users can update their own plans.
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'meal_plans' and column_name = 'saved_at';

select policyname, cmd from pg_policies
where schemaname = 'public' and tablename = 'meal_plans';
