-- ============================================================
-- NAHAM — إصلاح أخطاء شائعة بعد تشغيل سكربتات جزئية
--
-- يعالج:
--   1) chef_profiles_public: عمود created_at غير موجود
--   2) transition_order_status: تعارض نوع الإرجاع
--   3) is_admin() غير فريد (overload + DEFAULT يسبب 42725)
--
-- بعد نجاح هذا الملف، شغّل بالترتيب:
--   • supabase_rls_authorization_hardening.sql (كاملًا من البداية)
--   • supabase_admin_role_setup.sql (كاملًا، أو من قسم admin_logs فما بعد إن كان قد نفّذ جزئيًا)
--   • supabase_order_state_machine.sql (كاملًا)
--   • supabase_rls_orders_reels_approved_chef.sql إن كنت تستخدمه
-- ============================================================

begin;

-- ─── 1) أعمدة ناقثة على chef_profiles ثم الـ VIEW ───
alter table public.chef_profiles
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now(),
  add column if not exists warning_count integer not null default 0,
  add column if not exists approval_status text default 'pending';

create or replace view public.chef_profiles_public as
select
  id,
  kitchen_name,
  is_online,
  vacation_mode,
  working_hours_start,
  working_hours_end,
  bio,
  kitchen_city,
  approval_status,
  warning_count,
  created_at,
  updated_at
from public.chef_profiles;

-- ─── 2) transition_order_status — احذف القديم ثم أعد الإنشاء من supabase_order_state_machine.sql ───
drop function if exists public.transition_order_status(uuid, text, timestamptz);
drop function if exists public.transition_order_status(uuid, text);

-- (انسخ بلوك الدالة (E) من supabase_order_state_machine.sql هنا إن احتجت تشغيلًا منفصلًا،
--  أو شغّل الملف كاملًا بعد هذا الإصلاح.)

-- ─── 3) is_admin — احذف كل الأشكال ثم عرّف نسختين واضحتين (بدون DEFAULT على uuid) ───
drop function if exists public.is_admin() cascade;
drop function if exists public.is_admin(uuid) cascade;

create or replace function public.is_admin(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_uid
      and p.role = 'admin'
      and coalesce(p.is_blocked, false) = false
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin(auth.uid());
$$;

comment on function public.is_admin() is
  'Current session is an active (non-blocked) admin.';
comment on function public.is_admin(uuid) is
  'True if p_uid is an active (non-blocked) admin.';

-- ensure_admin يعتمد على is_admin
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

grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.ensure_admin() to authenticated;

-- ─── 4b) كميات المنيو — نوع إرجاع قديم يمنع CREATE OR REPLACE ───
-- CASCADE قد يحذف دوال تعتمد على increase_remaining_quantity؛ أعد تشغيل supabase_order_state_machine.sql بعد hardening.
drop function if exists public.decrease_remaining_quantity(uuid, integer) cascade;
drop function if exists public.increase_remaining_quantity(uuid, integer) cascade;

commit;

-- ============================================================
-- مهم: CASCADE أعلاه قد يكون حذف سياسات RLS مرتبطة بـ is_admin().
-- لذلك يجب إعادة تشغيل supabase_rls_authorization_hardening.sql كاملًا
-- (يقوم بـ DROP لكل السياسات على الجداول المستهدفة ثم إنشائها من جديد).
-- ============================================================
