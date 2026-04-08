-- ============================================================
-- NAHAM — Auto-expire pending orders with no chef response (5 minutes)
-- Run after supabase_order_state_machine.sql
--
-- 1) Customers can expire/cancel from paid_waiting_acceptance (same as pending).
-- 2) expire_stale_pending_orders(): SECURITY DEFINER batch for pg_cron / service_role.
--
-- Schedule (after enabling pg_cron in Supabase Dashboard → Database → Extensions):
--   SELECT cron.schedule(
--     'expire-pending-orders',
--     '* * * * *',
--     $$SELECT public.expire_stale_pending_orders();$$
--   );
-- ============================================================

begin;

-- Fix customer transitions: allow expire/cancel from paid_waiting_acceptance (was pending-only).
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

  if auth.uid() = v_order.customer_id then
    if not (
      v_old_status in ('pending', 'paid_waiting_acceptance')
      and new_status in ('cancelled_by_customer', 'expired')
    ) then
      raise exception 'Customer is not allowed to perform this transition';
    end if;
  elsif auth.uid() = v_order.chef_id then
    if new_status = 'expired' then
      if v_old_status not in ('pending', 'paid_waiting_acceptance') then
        raise exception 'Chef is not allowed to perform this transition';
      end if;
    elsif new_status not in ('accepted', 'preparing', 'ready', 'completed', 'cancelled_by_cook') then
      raise exception 'Chef is not allowed to perform this transition';
    end if;
  else
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

  if v_old_status in ('pending', 'paid_waiting_acceptance') and new_status in ('cancelled_by_customer', 'cancelled_by_cook', 'expired') then
    perform public.restore_order_stock_once(order_id);
  end if;

  return v_order;
end;
$$;

-- Batch expiry for background jobs (no JWT). Idempotent per row: only pending-like → expired.
create or replace function public.expire_stale_pending_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n int := 0;
  r record;
  v_old text;
begin
  for r in
    select id, status::text as st
    from public.orders
    where status in ('pending', 'paid_waiting_acceptance')
      and created_at < (timezone('utc', now()) - interval '5 minutes')
    for update skip locked
  loop
    v_old := r.st;

    update public.orders
    set status = 'expired'::public.order_status,
        updated_at = now()
    where id = r.id;

    insert into public.order_status_events(order_id, event_type, actor_id, from_status, to_status)
    values (r.id, 'status_transition', null, v_old, 'expired');

    if v_old in ('pending', 'paid_waiting_acceptance') then
      perform public.restore_order_stock_once(r.id);
    end if;

    n := n + 1;
  end loop;

  return n;
end;
$$;

revoke all on function public.expire_stale_pending_orders() from public;
grant execute on function public.expire_stale_pending_orders() to service_role;

comment on function public.expire_stale_pending_orders() is
  'Sets orders.status=expired when pending >5m since created_at; run via pg_cron every minute.';

commit;
