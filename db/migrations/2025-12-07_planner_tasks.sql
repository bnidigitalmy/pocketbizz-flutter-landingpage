-- Planner tasks table for PocketBizz
create table if not exists public.planner_tasks (
  id uuid primary key default uuid_generate_v4(),
  business_owner_id uuid not null references auth.users(id),
  title text not null,
  type text not null,                           -- manual | auto_*
  status text not null default 'open',          -- open|done|snoozed|dismissed
  priority text not null default 'normal',      -- low|normal|high|critical
  due_at timestamptz,
  remind_at timestamptz,
  snooze_until timestamptz,
  linked_type text,                             -- product|batch|order|vendor|claim|po|delivery|booking|shopping_item
  linked_id text,
  source text,                                  -- inventory|production|sales|claims|po|shopping|booking
  metadata jsonb,
  is_auto boolean not null default false,
  auto_hash text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Dedupe auto tasks
create unique index if not exists planner_tasks_auto_hash_idx
  on public.planner_tasks(auto_hash)
  where is_auto = true;

-- Helpful indexes
create index if not exists planner_tasks_owner_status_due_idx
  on public.planner_tasks(business_owner_id, status, due_at desc);

create index if not exists planner_tasks_owner_type_idx
  on public.planner_tasks(business_owner_id, type);

-- RLS
alter table public.planner_tasks enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'planner_tasks'
      and policyname = 'planner_tasks_select_own'
  ) then
    create policy "planner_tasks_select_own"
      on public.planner_tasks for select
      using (business_owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'planner_tasks'
      and policyname = 'planner_tasks_insert_own'
  ) then
    create policy "planner_tasks_insert_own"
      on public.planner_tasks for insert
      with check (business_owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'planner_tasks'
      and policyname = 'planner_tasks_update_own'
  ) then
    create policy "planner_tasks_update_own"
      on public.planner_tasks for update
      using (business_owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'planner_tasks'
      and policyname = 'planner_tasks_delete_own'
  ) then
    create policy "planner_tasks_delete_own"
      on public.planner_tasks for delete
      using (business_owner_id = auth.uid());
  end if;
end$$;


