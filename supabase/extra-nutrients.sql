-- Extra nutrients per dish and per logged food, beyond calories and macros.
-- Defaults of 0 keep older rows and hand-logged foods valid.

alter table public.meal_plan_items
  add column if not exists sugar_g numeric(6, 1) default 0,
  add column if not exists fiber_g numeric(6, 1) default 0,
  add column if not exists saturated_fat_g numeric(6, 1) default 0,
  add column if not exists sodium_mg numeric(7, 0) default 0,
  add column if not exists cholesterol_mg numeric(7, 0) default 0;

alter table public.food_logs
  add column if not exists sugar_g numeric(6, 1) default 0,
  add column if not exists fiber_g numeric(6, 1) default 0,
  add column if not exists saturated_fat_g numeric(6, 1) default 0,
  add column if not exists sodium_mg numeric(7, 0) default 0,
  add column if not exists cholesterol_mg numeric(7, 0) default 0;

notify pgrst, 'reload schema';

-- Verify: expect 10 rows.
select table_name, column_name from information_schema.columns
where table_schema = 'public'
  and table_name in ('meal_plan_items', 'food_logs')
  and column_name in ('sugar_g', 'fiber_g', 'saturated_fat_g', 'sodium_mg', 'cholesterol_mg')
order by table_name, column_name;
