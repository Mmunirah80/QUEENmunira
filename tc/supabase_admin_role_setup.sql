-- ============================================================
-- NAHAM - Admin role setup (production-safe baseline)
-- ============================================================
-- Includes:
-- - profiles role hardening + blocked flag
-- - admin_logs, support_tickets, support_ticket_messages
-- - moderation columns on chef_profiles/menu_items
-- - helper functions: is_admin(), ensure_admin()
-- - dashboard rpc: get_admin_dashboard_stats()
-- - RLS policies for admin-only operations
--
-- Run in Supabase SQL Editor as project owner.
-- ============================================================

begin;

-- 1) Profiles hardening
alter table public.profiles
  add column if not exists is_blocked boolean not null default false,
  add column if not exists blocked_reason text,
  add column if not exists blocked_at timestamptz;

-- Normalize role casing. [role] may be TEXT or an ENUM (e.g. user_role); lower() needs text.
do $$
declare
  role_att_oid oid;
  is_enum boolean;
  role_reg regtype;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'role'
  ) then
    return;
  end if;

  select a.atttypid into role_att_oid
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'profiles'
    and a.attname = 'role'
    and a.attnum > 0
    and not a.attisdropped;

  if role_att_oid is null then
    return;
  end if;

  select coalesce(max(t.typtype), '') = 'e' into is_enum
  from pg_type t
  where t.oid = role_att_oid;

  if is_enum then
    role_reg := role_att_oid::regtype;
    execute format(
      'update public.profiles set role = (lower(trim(role::text)))::%s where role is not null',
      role_reg
    );
  else
    update public.profiles
    set role = lower(trim(role::text))
    where role is not null;
  end if;
end $$;

-- Optional safety check for role values
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_allowed_values'
  ) then
    alter table public.profiles
      add constraint profiles_role_allowed_values
      check (role in ('customer', 'chef', 'admin'));
  end if;
end $$;

-- 2) Chef moderation columns
alter table public.chef_profiles
  add column if not exists suspended boolean not null default false,
  add column if not exists suspension_reason text,
  add column if not exists suspended_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id) on delete set null,
  add column if not exists reviewed_at timestamptz;

-- 3) Menu moderation columns
alter table public.menu_items
  add column if not exists moderation_status text not null default 'approved',
  add column if not exists moderation_reason text,
  add column if not exists moderated_by uuid references public.profiles(id) on delete set null,
  add column if not exists moderated_at timestamptz,
  add column if not exists is_flagged boolean not null default false,
  add column if not exists flagged_reason text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'menu_items_moderation_status_allowed_values'
  ) then
    alter table public.menu_items
      add constraint menu_items_moderation_status_allowed_values
      check (moderation_status in ('pending', 'approved', 'rejected'));
  end if;
end $$;

-- 4) Admin logs table
create table if not exists public.admin_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id) on delete restrict,
  action text not null,
  target_table text,
  target_id text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_admin_logs_admin_id_created_at
  on public.admin_logs(admin_id, created_at desc);

create index if not exists idx_admin_logs_action_created_at
  on public.admin_logs(action, created_at desc);

-- 5) Support tickets
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  assigned_admin_id uuid references public.profiles(id) on delete set null,
  subject text not null,
  status text not null default 'open',
  priority text not null default 'normal',
  last_message text,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'support_tickets_status_allowed_values'
  ) then
    alter table public.support_tickets
      add constraint support_tickets_status_allowed_values
      check (status in ('open', 'in_progress', 'resolved', 'closed'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'support_tickets_priority_allowed_values'
  ) then
    alter table public.support_tickets
      add constraint support_tickets_priority_allowed_values
      check (priority in ('low', 'normal', 'high', 'urgent'));
  end if;
end $$;

create index if not exists idx_support_tickets_status_updated_at
  on public.support_tickets(status, updated_at desc);

create index if not exists idx_support_tickets_customer_id_created_at
  on public.support_tickets(customer_id, created_at desc);

-- 6) Support ticket messages
create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  sender_role text not null,
  message text not null,
  is_internal boolean not null default false,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'support_ticket_messages_sender_role_allowed_values'
  ) then
    alter table public.support_ticket_messages
      add constraint support_ticket_messages_sender_role_allowed_values
      check (sender_role in ('customer', 'admin'));
  end if;
end $$;

create index if not exists idx_support_ticket_messages_ticket_created
  on public.support_ticket_messages(ticket_id, created_at);

-- 7) Role helpers — [is_admin(uuid)] + [is_admin()] are defined in
--    supabase_rls_authorization_hardening.sql (uuid has NO default; () delegates to auth.uid()).
--    Do NOT add is_admin(uuid DEFAULT auth.uid()) here: PostgreSQL treats is_admin() as ambiguous.

create or replace function public.ensure_admin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'admin access required';
  end if;
end;
$$;

-- 8) Dashboard RPC
create or replace function public.get_admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start timestamptz := date_trunc('day', now());
  v_orders_today integer := 0;
  v_revenue_today numeric := 0;
  v_active_chefs integer := 0;
  v_open_complaints integer := 0;
begin
  perform public.ensure_admin();

  select count(*)
    into v_orders_today
  from public.orders
  where created_at >= v_start;

  select coalesce(sum(total_amount), 0)
    into v_revenue_today
  from public.orders
  where created_at >= v_start
    and status in ('accepted', 'preparing', 'ready', 'completed');

  select count(*)
    into v_active_chefs
  from public.chef_profiles
  where coalesce(is_online, false) = true
    and coalesce(suspended, false) = false;

  if to_regclass('public.support_tickets') is not null then
    select count(*)
      into v_open_complaints
    from public.support_tickets
    where status in ('open', 'in_progress');
  end if;

  return jsonb_build_object(
    'orders_today', v_orders_today,
    'revenue_today', v_revenue_today,
    'active_chefs', v_active_chefs,
    'open_complaints', v_open_complaints
  );
end;
$$;

-- 9) Admin action logger RPC
create or replace function public.log_admin_action(
  p_action text,
  p_target_table text default null,
  p_target_id text default null,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  perform public.ensure_admin();

  insert into public.admin_logs(admin_id, action, target_table, target_id, payload)
  values (auth.uid(), p_action, p_target_table, p_target_id, coalesce(p_payload, '{}'::jsonb))
  returning id into v_id;

  return v_id;
end;
$$;

-- 10) RLS baseline
alter table public.admin_logs enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;

drop policy if exists "admin_logs_admin_only_select" on public.admin_logs;
create policy "admin_logs_admin_only_select"
on public.admin_logs
for select
using (public.is_admin(auth.uid()));

drop policy if exists "admin_logs_admin_only_insert" on public.admin_logs;
create policy "admin_logs_admin_only_insert"
on public.admin_logs
for insert
with check (public.is_admin(auth.uid()));

drop policy if exists "support_tickets_customer_own_select" on public.support_tickets;
create policy "support_tickets_customer_own_select"
on public.support_tickets
for select
using (customer_id = auth.uid());

drop policy if exists "support_tickets_customer_own_insert" on public.support_tickets;
create policy "support_tickets_customer_own_insert"
on public.support_tickets
for insert
with check (customer_id = auth.uid());

drop policy if exists "support_tickets_admin_all" on public.support_tickets;
create policy "support_tickets_admin_all"
on public.support_tickets
for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists "support_ticket_messages_customer_select" on public.support_ticket_messages;
create policy "support_ticket_messages_customer_select"
on public.support_ticket_messages
for select
using (
  exists (
    select 1
    from public.support_tickets t
    where t.id = ticket_id
      and t.customer_id = auth.uid()
  )
);

drop policy if exists "support_ticket_messages_customer_insert" on public.support_ticket_messages;
create policy "support_ticket_messages_customer_insert"
on public.support_ticket_messages
for insert
with check (
  sender_id = auth.uid()
  and sender_role = 'customer'
  and exists (
    select 1
    from public.support_tickets t
    where t.id = ticket_id
      and t.customer_id = auth.uid()
  )
);

drop policy if exists "support_ticket_messages_admin_all" on public.support_ticket_messages;
create policy "support_ticket_messages_admin_all"
on public.support_ticket_messages
for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- 11) Grants for authenticated users to call secure RPCs
grant execute on function public.get_admin_dashboard_stats() to authenticated;
grant execute on function public.log_admin_action(text, text, text, jsonb) to authenticated;
grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.ensure_admin() to authenticated;

commit;

