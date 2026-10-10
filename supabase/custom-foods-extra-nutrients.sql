-- Extra nutrients for saved foods, filled by the AI estimate on Custom Food.
-- Defaults of 0 keep older saved foods valid.

alter table public.custom_foods
  add column if not exists sugar_g numeric(6, 1) default 0,
  add column if not exists fiber_g numeric(6, 1) default 0,
  add column if not exists saturated_fat_g numeric(6, 1) default 0,
  add column if not exists sodium_mg numeric(7, 0) default 0,
  add column if not exists cholesterol_mg numeric(7, 0) default 0;

notify pgrst, 'reload schema';

-- Verify: expect 5 rows.
select column_name from information_schema.columns
where table_schema = 'public'
  and table_name = 'custom_foods'
  and column_name in ('sugar_g', 'fiber_g', 'saturated_fat_g', 'sodium_mg', 'cholesterol_mg')
order by column_name;
