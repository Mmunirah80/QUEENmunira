-- ============================================================
-- NAHAM - Orders state machine + single-source stock restore
-- ============================================================
-- This migration enforces:
-- 1) Valid order statuses (includes expired)
-- 2) Valid transitions only
-- 3) Terminal statuses are immutable (status-wise)
-- 4) transition_order_status RPC as the ONLY write path
-- 5) Stock restore happens ONCE in backend for cancel/expire from pending
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- A) Status allowed values
-- ------------------------------------------------------------------
alter table public.orders
drop constraint if exists orders_status_allowed_values;

alter table public.orders
add constraint orders_status_allowed_values
check (
  status in (
    'pending',
    'paid_waiting_acceptance',
    'accepted',
    'preparing',
    'ready',
    'completed',
    'cancelled_by_customer',
    'cancelled_by_cook',
    'cancelled_payment_failed',
    'expired'
  )
);

-- ------------------------------------------------------------------
-- B) Transition helper
-- ------------------------------------------------------------------
create or replace function public.is_valid_order_transition(
  p_old text,
  p_new text
)
returns boolean
language sql
immutable
as $$
  select case
    when p_old = p_new then true
    when p_old in ('pending', 'paid_waiting_acceptance') and p_new in (
      'accepted','cancelled_by_customer','cancelled_by_cook','cancelled_payment_failed','expired'
    ) then true
    when p_old = 'accepted' and p_new in ('preparing','cancelled_by_cook') then true
    when p_old = 'preparing' and p_new in ('ready','cancelled_by_cook') then true
    when p_old = 'ready' and p_new in ('completed','cancelled_by_cook') then true
    else false
  end;
$$;

-- ------------------------------------------------------------------
-- C) Guard trigger for all direct updates
-- ------------------------------------------------------------------
create or replace function public.orders_enforce_state_machine()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status then
    if not public.is_valid_order_transition(old.status, new.status) then
      raise exception 'Invalid order status transition: % -> %', old.status, new.status;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_state_machine on public.orders;
create trigger trg_orders_state_machine
before update on public.orders
for each row
execute function public.orders_enforce_state_machine();

-- ------------------------------------------------------------------
-- D) Idempotent stock restoration helper
-- ------------------------------------------------------------------
create table if not exists public.order_status_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null,
  actor_id uuid,
  from_status text,
  to_status text,
  created_at timestamptz not null default now()
);

create unique index if not exists ux_order_status_events_restore_once
  on public.order_status_events (order_id, event_type)
  where event_type = 'stock_restored';

create index if not exists idx_order_status_events_order_time
  on public.order_status_events (order_id, created_at desc);

create or replace function public.restore_order_stock_once(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  -- If already restored, do nothing.
  if exists (
    select 1
    from public.order_status_events e
    where e.order_id = p_order_id
      and e.event_type = 'stock_restored'
  ) then
    return;
  end if;

  for r in (
    select (oi.menu_item_id)::text as dish_id, oi.quantity
    from public.order_items oi
    where oi.order_id = p_order_id
  ) loop
    if r.dish_id is not null and r.dish_id <> '' and coalesce(r.quantity, 0) > 0 then
      perform public.increase_remaining_quantity(
        r.dish_id::uuid,
        r.quantity
      );
    end if;
  end loop;

  insert into public.order_status_events(order_id, event_type, actor_id)
  values (p_order_id, 'stock_restored', auth.uid())
  on conflict do nothing;
end;
$$;

-- ------------------------------------------------------------------
-- E) transition_order_status RPC (single write path)
-- ------------------------------------------------------------------
-- Chef-side decline of a pending/active order uses status cancelled_by_cook (not legacy "rejected").
-- Clients should call this RPC only; direct UPDATE is guarded by trg_orders_state_machine.
-- ------------------------------------------------------------------
-- If an older migration returned a different type, CREATE OR REPLACE is not enough — drop first.
drop function if exists public.transition_order_status(uuid, text, timestamptz);
drop function if exists public.transition_order_status(uuid, text);

create or replace function public.transition_order_status(
  order_id uuid,
  new_status text,
  expected_updated_at timestamptz default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_old_status text;
begin
  select * into v_order
  from public.orders
  where id = order_id
  for update;

  if not found then
    raise exception 'Order not found';
  end if;

  if expected_updated_at is not null and v_order.updated_at is distinct from expected_updated_at then
    raise exception 'Order was updated by another process';
  end if;

  v_old_status := v_order.status;

  -- Ownership checks
  if auth.uid() = v_order.customer_id then
    if not (v_old_status = 'pending' and new_status in ('cancelled_by_customer', 'expired')) then
      raise exception 'Customer is not allowed to perform this transition';
    end if;
  elsif auth.uid() = v_order.chef_id then
    -- Chefs may expire unanswered "new" orders (same terminal outcome as customer expiry).
    if new_status = 'expired' then
      if v_old_status not in ('pending', 'paid_waiting_acceptance') then
        raise exception 'Chef is not allowed to perform this transition';
      end if;
    elsif new_status not in ('accepted', 'preparing', 'ready', 'completed', 'cancelled_by_cook') then
      raise exception 'Chef is not allowed to perform this transition';
    end if;
  else
    -- Optional admin bypass
    if not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    ) then
      raise exception 'Not authorized to transition this order';
    end if;
  end if;

  update public.orders o
  set status = new_status::public.order_status,
      updated_at = now()
  where o.id = order_id
  returning * into v_order;

  insert into public.order_status_events(order_id, event_type, actor_id, from_status, to_status)
  values (order_id, 'status_transition', auth.uid(), v_old_status, new_status);

  -- Restore stock once for terminal cancellation/expiry from pending.
  if v_old_status in ('pending', 'paid_waiting_acceptance') and new_status in ('cancelled_by_customer', 'cancelled_by_cook', 'expired') then
    perform public.restore_order_stock_once(order_id);
  end if;

  return v_order;
end;
$$;

grant execute on function public.transition_order_status(uuid, text, timestamptz) to authenticated;
grant execute on function public.restore_order_stock_once(uuid) to authenticated;

commit;

