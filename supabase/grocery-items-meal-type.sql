-- Records which meal each grocery item is for, so Grocery can group by meal.

alter table public.grocery_items
  add column if not exists meal_type text;

-- Lists built before this column existed have no meal; clear them so they rebuild.
delete from public.grocery_items where meal_type is null and plan_id is not null;

-- Verify.
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'grocery_items' and column_name = 'meal_type';
