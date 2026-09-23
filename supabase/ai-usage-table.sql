-- One row per AI generation attempt, used for the daily cap and usage reporting.

create table if not exists public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  feature text not null,
  model text not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_user_time_idx
  on public.ai_usage (user_id, created_at desc);

alter table public.ai_usage enable row level security;

create policy "Users can read their own usage"
  on public.ai_usage for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their own usage"
  on public.ai_usage for insert to authenticated
  with check (auth.uid() = user_id);

-- No update or delete policy, so users cannot reset their own daily count.
grant select, insert on public.ai_usage to authenticated;
revoke truncate on public.ai_usage from authenticated, anon;

-- Verify.
select policyname, cmd from pg_policies
where schemaname = 'public' and tablename = 'ai_usage';
