-- ============================================================
-- Chef enforcement ladder (admin): warning → freeze 3/7/14d → block
-- Run in Supabase SQL Editor after core schema exists.
--
-- Adds (if missing):
--   chef_profiles.warning_count, freeze_level, freeze_until
-- Block uses public.profiles.is_blocked (same as auth elsewhere in the app).
-- Single RPC: admin_chef_take_enforcement_action(p_chef_id uuid)
--
-- Orders: uses status 'cancelled_by_system' for system-cancelled pending rows.
-- Run `supabase_orders_cancelled_by_system_v1.sql` if your DB still uses the older
-- `orders_status_allowed_values` without `cancelled_by_system` (and matching `is_valid_order_transition`).
-- ============================================================

alter table public.chef_profiles
  add column if not exists warning_count integer not null default 0;

alter table public.chef_profiles
  add column if not exists freeze_until timestamptz null;

alter table public.chef_profiles
  add column if not exists freeze_level int not null default 0;

comment on column public.chef_profiles.freeze_level is
  'Escalation tier after warnings: 0 = no freeze yet; 1 after first freeze window; 2 after second; 3 after third; block uses profiles.is_blocked.';

-- Optional: document is_blocked remains on public.profiles (single source for auth UX).

create or replace function public.admin_chef_take_enforcement_action(p_cook_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_w int;
  v_fl int;
  v_until timestamptz;
begin
  perform public.ensure_admin();

  select coalesce(warning_count, 0), coalesce(freeze_level, 0)
    into v_w, v_fl
  from public.chef_profiles
  where id = p_cook_id;

  if not found then
    raise exception 'chef profile not found';
  end if;

  -- 1) First step: issue warning (sets warning_count to 1)
  if v_w = 0 then
    update public.chef_profiles
    set warning_count = 1
    where id = p_cook_id;
    return jsonb_build_object('action', 'warning', 'warning_count', 1);
  end if;

  -- 2) Freeze 3 days
  if v_fl = 0 then
    v_until := (now() at time zone 'utc') + interval '3 days';
    update public.chef_profiles
    set
      freeze_until = v_until,
      freeze_started_at = now(),
      freeze_type = 'soft',
      freeze_level = 1,
      is_online = false
    where id = p_cook_id;

    update public.orders
    set status = 'cancelled_by_system'
    where chef_id = p_cook_id
      and status = 'pending';

    return jsonb_build_object('action', 'freeze_3d', 'freeze_until', v_until, 'freeze_level', 1);
  end if;

  -- 3) Freeze 7 days
  if v_fl = 1 then
    v_until := (now() at time zone 'utc') + interval '7 days';
    update public.chef_profiles
    set
      freeze_until = v_until,
      freeze_started_at = now(),
      freeze_level = 2,
      is_online = false
    where id = p_cook_id;

    update public.orders
    set status = 'cancelled_by_system'
    where chef_id = p_cook_id
      and status = 'pending';

    return jsonb_build_object('action', 'freeze_7d', 'freeze_until', v_until, 'freeze_level', 2);
  end if;

  -- 4) Freeze 14 days
  if v_fl = 2 then
    v_until := (now() at time zone 'utc') + interval '14 days';
    update public.chef_profiles
    set
      freeze_until = v_until,
      freeze_started_at = now(),
      freeze_level = 3,
      is_online = false
    where id = p_cook_id;

    update public.orders
    set status = 'cancelled_by_system'
    where chef_id = p_cook_id
      and status = 'pending';

    return jsonb_build_object('action', 'freeze_14d', 'freeze_until', v_until, 'freeze_level', 3);
  end if;

  -- 5) Block chef (profiles.is_blocked — same as rest of app)
  if v_fl = 3 then
    update public.profiles
    set is_blocked = true
    where id = p_cook_id;
    return jsonb_build_object('action', 'blocked');
  end if;

  raise exception 'unexpected state warning_count=% freeze_level=%', v_w, v_fl;
end;
$$;

grant execute on function public.admin_chef_take_enforcement_action(uuid) to authenticated;
