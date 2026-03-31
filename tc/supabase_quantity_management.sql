-- ============================================================
-- Quantity management RPCs (Cook daily capacity <-> Customer cart)
-- ============================================================
-- If you see 42P13 "cannot change return type", the DROPs below clear the old signature.
-- Goal:
-- 1) Atomically decrement menu_items.remaining_quantity
--    so multiple customers can order safely.
-- 2) Atomically increment it back on cancellation.
--
-- IMPORTANT:
-- - Run in Supabase SQL Editor.
-- - Ensure customers are allowed to EXECUTE these RPCs.
-- - We use SECURITY DEFINER to bypass RLS for the update.
-- ============================================================

-- CASCADE if restore_order_stock_once depends on increase_* — then re-run supabase_order_state_machine.sql
drop function if exists public.decrease_remaining_quantity(uuid, integer) cascade;
drop function if exists public.increase_remaining_quantity(uuid, integer) cascade;

create or replace function public.decrease_remaining_quantity(
  p_dish_id uuid,
  p_quantity integer
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_remaining integer;
  v_ok boolean := false;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('ok', false, 'remaining_quantity', 0);
  end if;

  update public.menu_items
  set remaining_quantity = remaining_quantity - p_quantity
  where id = p_dish_id
    and remaining_quantity >= p_quantity
  returning remaining_quantity into v_remaining;

  if found then
    v_ok := true;
  else
    select remaining_quantity into v_remaining
    from public.menu_items
    where id = p_dish_id;
    v_remaining := coalesce(v_remaining, 0);
    v_ok := false;
  end if;

  return jsonb_build_object('ok', v_ok, 'remaining_quantity', coalesce(v_remaining, 0));
end;
$$;

create or replace function public.increase_remaining_quantity(
  p_dish_id uuid,
  p_quantity integer
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_remaining integer;
  v_cap integer;
  v_found boolean := false;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('ok', false, 'remaining_quantity', 0);
  end if;

  select daily_quantity into v_cap
  from public.menu_items
  where id = p_dish_id;

  update public.menu_items
  set remaining_quantity =
    case
      when v_cap is null then remaining_quantity + p_quantity
      else least(remaining_quantity + p_quantity, v_cap)
    end
  where id = p_dish_id
  returning remaining_quantity into v_remaining;

  if found then
    v_found := true;
  end if;

  return jsonb_build_object('ok', v_found, 'remaining_quantity', coalesce(v_remaining, 0));
end;
$$;

