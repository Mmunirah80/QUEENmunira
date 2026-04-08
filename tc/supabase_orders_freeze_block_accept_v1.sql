-- ============================================================
-- NAHAM — منع قبول الطلبات من الطاهي أثناء التجميد النشط (DB)
-- يُشغَّل بعد trg_orders_state_machine (اسم zzz_ يضمن الترتيب الأبجدي).
--
-- السياق: التجميد الناعم (soft) من إنفاذ الإدارة يمنع طلباتاً جديدة عبر RLS،
-- لكن العميل قد يحاول قبول طلب معلّق عبر RPC/تحديث مباشر — هذا المحفّز يمنع ذلك.
--
-- تشغيل: بعد chef_profiles.freeze_until ووجود محفّزات orders الحالية.
-- ============================================================

create or replace function public.orders_enforce_freeze_no_accept_when_active()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fu timestamptz;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.chef_id is distinct from old.chef_id then
    return new;
  end if;

  if old.status not in ('pending', 'paid_waiting_acceptance') then
    return new;
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  -- قارن كنص لدعم enum أو text
  if new.status::text is distinct from 'accepted' then
    return new;
  end if;

  select cp.freeze_until into v_fu
  from public.chef_profiles cp
  where cp.id = new.chef_id;

  if v_fu is null or v_fu <= now() then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if auth.uid() is not distinct from new.chef_id then
    raise exception 'Account frozen: cannot accept new orders until the freeze period ends.';
  end if;

  return new;
end;
$$;

comment on function public.orders_enforce_freeze_no_accept_when_active() is
  'Blocks pending→accepted while chef_profiles.freeze_until > now (any freeze type). Admins bypass.';

drop trigger if exists zzz_orders_enforce_freeze_no_accept_trg on public.orders;

create trigger zzz_orders_enforce_freeze_no_accept_trg
  before update on public.orders
  for each row
  execute function public.orders_enforce_freeze_no_accept_when_active();
