-- Other dish options per planned meal, so users can pick one without a new AI call.

alter table public.meal_plan_items
  add column if not exists alternatives jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';

-- Verify: expect 1 row.
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'meal_plan_items'
  and column_name = 'alternatives';
