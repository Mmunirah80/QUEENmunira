-- ============================================================
-- NAHAM — Cook freeze policy (soft / hard), enforcement
-- Run in Supabase SQL Editor after core schema exists.
--
-- Adds: freeze_started_at, freeze_type, freeze_reason on chef_profiles
-- Replaces: admin_cook_set_freeze (sets is_online=false on freeze)
-- Triggers: chefs cannot edit freeze fields or go online while frozen;
--           hard freeze blocks cook from accepting/advancing orders
-- RLS: orders_insert_customer rejects any active freeze (soft or hard)
-- ============================================================

-- 1) Columns ---------------------------------------------------------------
alter table public.chef_profiles
  add column if not exists freeze_started_at timestamptz,
  add column if not exists freeze_type text,
  add column if not exists freeze_reason text;

comment on column public.chef_profiles.freeze_until is
  'Cook cannot receive new orders until this instant (UTC). Countdown starts when admin applies freeze.';
comment on column public.chef_profiles.freeze_started_at is
  'When the current freeze period was applied.';
comment on column public.chef_profiles.freeze_type is
  'soft = default: no new orders, may work existing orders. hard = cannot accept/advance active pipeline (reject allowed).';
comment on column public.chef_profiles.freeze_reason is
  'Optional admin note shown to Cook in app when present.';

-- 2) Chef profile: freeze metadata is admin/RPC-only; block online while frozen
create or replace function public.chef_profiles_enforce_freeze_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if auth.uid() is distinct from new.id then
    return new;
  end if;

  -- Chefs cannot alter freeze fields directly (only via admin RPC / admin row update)
  new.freeze_until := old.freeze_until;
  new.freeze_started_at := old.freeze_started_at;
  new.freeze_type := old.freeze_type;
  new.freeze_reason := old.freeze_reason;

  if coalesce(new.is_online, false) = true
     and old.freeze_until is not null
     and old.freeze_until > now() then
    raise exception 'Cook account is frozen: cannot turn on availability until the freeze ends.';
  end if;

  return new;
end;
$$;

drop trigger if exists chef_profiles_enforce_freeze_rules_trg on public.chef_profiles;
create trigger chef_profiles_enforce_freeze_rules_trg
  before update on public.chef_profiles
  for each row
  execute function public.chef_profiles_enforce_freeze_rules();

-- 3) Orders: hard freeze — cook cannot accept or advance active orders
create or replace function public.orders_enforce_hard_freeze()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ft text;
  v_fu timestamptz;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.chef_id is distinct from old.chef_id then
    return new;
  end if;

  select cp.freeze_type, cp.freeze_until
    into v_ft, v_fu
  from public.chef_profiles cp
  where cp.id = new.chef_id;

  if v_fu is null or v_fu <= now() or lower(coalesce(v_ft, '')) is distinct from 'hard' then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if auth.uid() is distinct from new.chef_id then
    return new;
  end if;

  if old.status in ('pending', 'paid_waiting_acceptance')
     and new.status is distinct from old.status then
    if new.status in (
      'rejected',
      'cancelled_by_cook',
      'cancelled',
      'cancelled_by_customer',
      'expired'
    ) then
      return new;
    end if;
    raise exception 'Hard freeze: cannot accept this order. You may still reject or cancel where allowed.';
  end if;

  if old.status in ('accepted', 'preparing', 'ready')
     and new.status is distinct from old.status then
    raise exception 'Hard freeze: cannot advance or complete orders. Contact support if you need help.';
  end if;

  return new;
end;
$$;

drop trigger if exists orders_enforce_hard_freeze_trg on public.orders;
create trigger orders_enforce_hard_freeze_trg
  before update on public.orders
  for each row
  execute function public.orders_enforce_hard_freeze();

-- 3b) Active freeze (incl. soft): block pending→accepted — run supabase_orders_freeze_block_accept_v1.sql

-- 4) Admin RPC -------------------------------------------------------------
drop function if exists public.admin_cook_set_freeze(uuid, timestamptz);

create or replace function public.admin_cook_set_freeze(
  p_cook_id uuid,
  p_until timestamptz,
  p_freeze_type text default null,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
begin
  perform public.ensure_admin();

  if p_until is null then
    update public.chef_profiles
    set
      freeze_until = null,
      freeze_started_at = null,
      freeze_type = null,
      freeze_reason = null
    where id = p_cook_id;
    return;
  end if;

  v_type := lower(trim(coalesce(p_freeze_type, 'soft')));
  if v_type not in ('soft', 'hard') then
    raise exception 'freeze_type must be soft or hard';
  end if;

  update public.chef_profiles
  set
    freeze_until = p_until,
    freeze_started_at = now(),
    freeze_type = v_type,
    freeze_reason = nullif(trim(p_reason), ''),
    is_online = false
  where id = p_cook_id;
end;
$$;

grant execute on function public.admin_cook_set_freeze(uuid, timestamptz, text, text) to authenticated;

-- 5) Customer order insert: block new orders for any active freeze ----------
drop policy if exists orders_insert_customer on public.orders;

create policy orders_insert_customer
  on public.orders for insert
  to authenticated
  with check (
    public.auth_is_active_user ()
    and public.auth_role () = 'customer'
    and customer_id = auth.uid ()
    and exists (
      select 1
      from public.chef_profiles cp
      where cp.id = orders.chef_id
        and cp.approval_status = 'approved'
        and coalesce (cp.suspended, false) = false
        and coalesce (cp.is_online, false) = true
        and (cp.freeze_until is null or cp.freeze_until <= now())
    )
  );

comment on policy orders_insert_customer on public.orders is
  'Customers may only place orders with approved, non-suspended, online cooks who are not in an active freeze.';
