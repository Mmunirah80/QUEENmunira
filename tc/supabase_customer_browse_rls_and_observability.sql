-- ============================================================
-- Customer browse RLS alignment + observability helpers
-- ============================================================
-- Apply after core admin/state-machine migrations.

begin;

-- ------------------------------------------------------------
-- 1) Read-side moderation alignment for customer browse
-- ------------------------------------------------------------
alter table public.chef_profiles
  add column if not exists approval_status text;

alter table public.chef_profiles
  add column if not exists suspended boolean not null default false;

alter table public.menu_items
  add column if not exists moderation_status text;

-- Safety checks (do not break legacy null rows)
alter table public.chef_profiles
  drop constraint if exists chef_profiles_approval_status_allowed;
alter table public.chef_profiles
  add constraint chef_profiles_approval_status_allowed
  check (
    approval_status is null
    or approval_status in ('pending', 'approved', 'rejected')
  );

alter table public.menu_items
  drop constraint if exists menu_items_moderation_status_allowed;
alter table public.menu_items
  add constraint menu_items_moderation_status_allowed
  check (
    moderation_status is null
    or moderation_status in ('pending', 'approved', 'rejected')
  );

-- ------------------------------------------------------------
-- 2) RLS policies: customer can only see approved/safe entities
-- ------------------------------------------------------------
alter table public.chef_profiles enable row level security;
alter table public.menu_items enable row level security;

drop policy if exists customer_read_approved_chefs on public.chef_profiles;
create policy customer_read_approved_chefs
on public.chef_profiles
for select
to authenticated
using (
  is_online = true
  and coalesce(vacation_mode, false) = false
  and coalesce(suspended, false) = false
  and coalesce(approval_status, 'approved') = 'approved'
);

drop policy if exists customer_read_approved_menu_items on public.menu_items;
create policy customer_read_approved_menu_items
on public.menu_items
for select
to authenticated
using (
  is_available = true
  and coalesce(remaining_quantity, 0) > 0
  and coalesce(moderation_status, 'approved') = 'approved'
);

-- ------------------------------------------------------------
-- 3) Observability view for operations
-- ------------------------------------------------------------
create or replace view public.v_customer_order_health as
select
  o.id as order_id,
  o.customer_id,
  o.chef_id,
  o.status,
  o.created_at,
  o.updated_at,
  extract(epoch from (now() - o.created_at))/60.0 as age_minutes,
  exists (
    select 1
    from public.order_status_events e
    where e.order_id = o.id and e.event_type = 'stock_restored'
  ) as stock_restored_once
from public.orders o;

-- ------------------------------------------------------------
-- 4) Alert helper function (for cron/ops dashboards)
-- ------------------------------------------------------------
create or replace function public.get_customer_flow_alerts(
  p_pending_minutes int default 15
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pending_stale int;
  v_invalid_transition_attempts int;
  v_stock_restore_duplicates int;
begin
  select count(*)
  into v_pending_stale
  from public.orders
  where status = 'pending'
    and created_at < now() - make_interval(mins => p_pending_minutes);

  select count(*)
  into v_invalid_transition_attempts
  from public.order_status_events
  where event_type = 'invalid_transition_attempt'
    and created_at > now() - interval '24 hours';

  select count(*)
  into v_stock_restore_duplicates
  from (
    select order_id
    from public.order_status_events
    where event_type = 'stock_restored'
    group by order_id
    having count(*) > 1
  ) x;

  return jsonb_build_object(
    'pending_stale_count', v_pending_stale,
    'invalid_transition_attempts_24h', v_invalid_transition_attempts,
    'stock_restore_duplicates', v_stock_restore_duplicates
  );
end;
$$;

grant select on public.v_customer_order_health to authenticated;
grant execute on function public.get_customer_flow_alerts(int) to authenticated;

commit;

