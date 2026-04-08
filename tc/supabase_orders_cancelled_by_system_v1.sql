-- ============================================================
-- NAHAM — Allow orders.status = cancelled_by_system + valid transitions
-- Run after supabase_order_state_machine.sql (or merge into your migration chain).
--
-- Needed for admin enforcement RPC that cancels pending rows when freezing a chef.
-- ============================================================

begin;

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
      'cancelled_by_system',
      'cancelled_payment_failed',
      'expired',
      'rejected'
    )
  );

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
      'accepted',
      'cancelled_by_customer',
      'cancelled_by_cook',
      'cancelled_by_system',
      'cancelled_payment_failed',
      'expired'
    ) then true
    when p_old = 'accepted' and p_new in ('preparing', 'cancelled_by_cook') then true
    when p_old = 'preparing' and p_new in ('ready', 'cancelled_by_cook') then true
    when p_old = 'ready' and p_new in ('completed', 'cancelled_by_cook') then true
    else false
  end;
$$;

commit;
