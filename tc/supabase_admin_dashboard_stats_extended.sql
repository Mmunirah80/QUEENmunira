-- NAHAM — Extended admin dashboard metrics (run in Supabase SQL Editor as admin).
-- Extends public.get_admin_dashboard_stats() return JSON with additional keys.
-- Existing keys remain for backward compatibility.

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
  v_total_users integer := 0;
  v_total_cooks integer := 0;
  v_total_customers integer := 0;
  v_total_admins integer := 0;
  v_pending_applications integer := 0;
  v_active_orders integer := 0;
  v_frozen_accounts integer := 0;
  v_open_chats integer := 0;
  v_reported_content integer := 0;
  v_docs_approved integer := 0;
  v_docs_rejected integer := 0;
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

  select count(*) into v_total_users from public.profiles;
  select count(*) into v_total_cooks from public.profiles where lower(trim(role::text)) = 'chef';
  select count(*) into v_total_customers from public.profiles where lower(trim(role::text)) = 'customer';
  select count(*) into v_total_admins from public.profiles where lower(trim(role::text)) = 'admin';

  if to_regclass('public.chef_documents') is not null then
    select count(*) into v_pending_applications
    from public.chef_documents
    where lower(trim(status::text)) in ('pending', 'pending_review');
    select count(*) into v_docs_approved
    from public.chef_documents
    where lower(trim(status::text)) = 'approved';
    select count(*) into v_docs_rejected
    from public.chef_documents
    where lower(trim(status::text)) = 'rejected';
  end if;

  select count(*) into v_active_orders
  from public.orders
  where status in (
    'paid_waiting_acceptance',
    'pending',
    'accepted',
    'preparing',
    'ready'
  );

  select count(distinct p.id) into v_frozen_accounts
  from public.profiles p
  left join public.chef_profiles cp on cp.id = p.id
  where p.is_blocked = true
     or (cp.freeze_until is not null and cp.freeze_until > now());

  if to_regclass('public.conversations') is not null then
    select count(*) into v_open_chats from public.conversations;
  end if;

  -- Placeholder until a reports table exists; keep at 0 or wire reel_reports etc.
  v_reported_content := 0;

  return jsonb_build_object(
    'orders_today', v_orders_today,
    'revenue_today', v_revenue_today,
    'active_chefs', v_active_chefs,
    'open_complaints', v_open_complaints,
    'total_users', v_total_users,
    'total_cooks', v_total_cooks,
    'total_customers', v_total_customers,
    'total_admins', v_total_admins,
    'pending_applications', v_pending_applications,
    'active_orders', v_active_orders,
    'frozen_accounts', v_frozen_accounts,
    'open_chats', v_open_chats,
    'reported_content', v_reported_content,
    'documents_approved_total', v_docs_approved,
    'documents_rejected_total', v_docs_rejected
  );
end;
$$;

grant execute on function public.get_admin_dashboard_stats() to authenticated;
