-- Lets users remove their own food log rows, needed for un-logging a planned meal.

drop policy if exists "Users can delete their own logs" on public.food_logs;

create policy "Users can delete their own logs"
  on public.food_logs for delete to authenticated
  using (auth.uid() = user_id);

grant delete on public.food_logs to authenticated;

-- Verify policies and that 'plan' is an allowed source value.
select policyname, cmd from pg_policies
where schemaname = 'public' and tablename = 'food_logs';

select conname, pg_get_constraintdef(oid) from pg_constraint
where conrelid = 'public.food_logs'::regclass and contype = 'c';
