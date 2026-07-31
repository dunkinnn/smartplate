-- Saved food library, so a food typed once can be reused when logging.
-- Separate from food_logs: this is the definition, food_logs is the event.

create table if not exists public.custom_foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  quantity text,
  kcal integer not null default 0 check (kcal >= 0),
  protein_g numeric(6, 1) default 0,
  carbs_g numeric(6, 1) default 0,
  fat_g numeric(6, 1) default 0,
  last_used_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- One entry per food name per user; re-creating the same name updates it.
-- Plain columns, not lower(name): PostgREST's on_conflict cannot target an
-- expression index.
create unique index if not exists custom_foods_user_name_idx
  on public.custom_foods (user_id, name);

create index if not exists custom_foods_recent_idx
  on public.custom_foods (user_id, last_used_at desc);

alter table public.custom_foods enable row level security;

create policy "Users can read their own foods"
  on public.custom_foods for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their own foods"
  on public.custom_foods for insert to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own foods"
  on public.custom_foods for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can delete their own foods"
  on public.custom_foods for delete to authenticated
  using (auth.uid() = user_id);

-- This project does not grant automatically on new tables.
grant select, insert, update, delete on public.custom_foods to authenticated;
revoke truncate on public.custom_foods from authenticated, anon;

-- Verify.
select policyname, cmd from pg_policies
where schemaname = 'public' and tablename = 'custom_foods';
