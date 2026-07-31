-- PostgREST's on_conflict accepts column names only, not expressions, so the
-- lower(name) index cannot be used as a conflict target. Swap it for a plain
-- unique index on the two columns.

drop index if exists public.custom_foods_user_name_idx;

create unique index if not exists custom_foods_user_name_idx
  on public.custom_foods (user_id, name);

-- Verify.
select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename = 'custom_foods';
