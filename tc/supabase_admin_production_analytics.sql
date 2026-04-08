-- =============================================================================
-- NAHAM — Production admin analytics & alerts (Supabase SQL Editor)
-- Prerequisites: public.ensure_admin() from supabase_admin_role_setup.sql
-- Run after: orders, order_items, profiles, chef_profiles, chef_documents,
--            conversations, reels exist.
-- =============================================================================

alter table public.profiles
  add column if not exists created_at timestamptz default now();

-- -----------------------------------------------------------------------------
-- 1) Extend dashboard stats: completed orders + optional reel report count
-- -----------------------------------------------------------------------------
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
  v_completed_orders integer := 0;
  v_frozen_accounts integer := 0;
  v_open_chats integer := 0;
  v_reported_content integer := 0;
  v_docs_approved integer := 0;
  v_docs_rejected integer := 0;
  v_prev_start timestamptz := date_trunc('day', now() - interval '1 day');
  v_prev_end timestamptz := date_trunc('day', now());
  v_orders_prev_day integer := 0;
  v_users_prev_week integer := 0;
  v_users_now integer := 0;
begin
  perform public.ensure_admin();

  select count(*) into v_orders_today from public.orders where created_at >= v_start;
  select count(*) into v_orders_prev_day
  from public.orders where created_at >= v_prev_start and created_at < v_prev_end;

  select coalesce(sum(total_amount), 0) into v_revenue_today
  from public.orders
  where created_at >= v_start
    and status in ('accepted', 'preparing', 'ready', 'completed');

  select count(*) into v_active_chefs
  from public.chef_profiles
  where coalesce(is_online, false) = true and coalesce(suspended, false) = false;

  if to_regclass('public.support_tickets') is not null then
    select count(*) into v_open_complaints
    from public.support_tickets where status in ('open', 'in_progress');
  end if;

  select count(*) into v_total_users from public.profiles;
  select count(*) into v_total_cooks from public.profiles where lower(trim(role::text)) = 'chef';
  select count(*) into v_total_customers from public.profiles where lower(trim(role::text)) = 'customer';
  select count(*) into v_total_admins from public.profiles where lower(trim(role::text)) = 'admin';

  select count(*) into v_users_now
  from public.profiles where created_at <= now();
  select count(*) into v_users_prev_week
  from public.profiles where created_at <= (now() - interval '7 days');

  if to_regclass('public.chef_documents') is not null then
    select count(*) into v_pending_applications
    from public.chef_documents where lower(trim(status::text)) = 'pending';
    select count(*) into v_docs_approved
    from public.chef_documents where lower(trim(status::text)) = 'approved';
    select count(*) into v_docs_rejected
    from public.chef_documents where lower(trim(status::text)) = 'rejected';
  end if;

  select count(*) into v_active_orders
  from public.orders
  where status in ('paid_waiting_acceptance','pending','accepted','preparing','ready');

  select count(*) into v_completed_orders
  from public.orders where status = 'completed';

  select count(distinct p.id) into v_frozen_accounts
  from public.profiles p
  left join public.chef_profiles cp on cp.id = p.id
  where p.is_blocked = true
     or (cp.freeze_until is not null and cp.freeze_until > now());

  if to_regclass('public.conversations') is not null then
    select count(*) into v_open_chats from public.conversations;
  end if;

  v_reported_content := 0;
  if to_regclass('public.reel_reports') is not null then
    select count(*) into v_reported_content
    from public.reel_reports
    where coalesce(lower(trim(status::text)), 'open') in ('open', 'pending', 'new');
  end if;

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
    'completed_orders', v_completed_orders,
    'frozen_accounts', v_frozen_accounts,
    'open_chats', v_open_chats,
    'reported_content', v_reported_content,
    'documents_approved_total', v_docs_approved,
    'documents_rejected_total', v_docs_rejected,
    'trend_orders_vs_yesterday_pct',
      case when v_orders_prev_day > 0
        then round(((v_orders_today::numeric - v_orders_prev_day) / v_orders_prev_day) * 100, 1)
        else null end,
    'trend_users_vs_week_ago_pct',
      case when v_users_prev_week > 0
        then round(((v_users_now::numeric - v_users_prev_week) / v_users_prev_week) * 100, 1)
        else null end
  );
end;
$$;

grant execute on function public.get_admin_dashboard_stats() to authenticated;

-- -----------------------------------------------------------------------------
-- 2) Analytics bundle: time series + rankings (real aggregations)
-- -----------------------------------------------------------------------------
create or replace function public.get_admin_analytics_bundle(
  p_daily_days integer default 30,
  p_monthly_months integer default 6,
  p_hour_lookback_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_daily_days int := greatest(1, least(coalesce(p_daily_days, 30), 120));
  v_monthly_months int := greatest(1, least(coalesce(p_monthly_months, 6), 24));
  v_hour_days int := greatest(1, least(coalesce(p_hour_lookback_days, 30), 90));
begin
  perform public.ensure_admin();

  return jsonb_build_object(
    'orders_by_day',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'date', d::text,
          'count', c
        ) order by d)
        from (
          select date_trunc('day', o.created_at)::date as d, count(*)::int as c
          from public.orders o
          where o.created_at >= (current_date - (v_daily_days || ' days')::interval)
          group by 1
          order by 1
        ) s
      ), '[]'::jsonb),
    'revenue_by_day',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'date', d::text,
          'amount', a
        ) order by d)
        from (
          select date_trunc('day', o.created_at)::date as d,
                 coalesce(sum(o.total_amount), 0)::numeric as a
          from public.orders o
          where o.created_at >= (current_date - (v_daily_days || ' days')::interval)
            and o.status in ('accepted','preparing','ready','completed')
          group by 1
          order by 1
        ) s
      ), '[]'::jsonb),
    'orders_by_month',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'month', m,
          'count', c
        ) order by m)
        from (
          select to_char(date_trunc('month', o.created_at), 'YYYY-MM') as m,
                 count(*)::int as c
          from public.orders o
          where o.created_at >= (date_trunc('month', now()) - ((v_monthly_months - 1) || ' months')::interval)
          group by 1
          order by 1
        ) s
      ), '[]'::jsonb),
    'top_requested_cooks',
      coalesce((
        select jsonb_agg(obj order by ord)
        from (
          select jsonb_build_object(
            'chef_id', q.chef_id,
            'name', coalesce(nullif(trim(q.chef_name), ''), cp.kitchen_name, q.chef_id::text),
            'order_count', q.cnt
          ) as obj,
          row_number() over (order by q.cnt desc) as ord
          from (
            select o.chef_id, max(o.chef_name) as chef_name, count(*)::int as cnt
            from public.orders o
            where o.chef_id is not null
              and o.created_at >= (now() - (v_daily_days || ' days')::interval)
            group by o.chef_id
          ) q
          left join public.chef_profiles cp on cp.id = q.chef_id
          order by q.cnt desc
          limit 15
        ) s
      ), '[]'::jsonb),
    'top_selling_dishes',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'dish_name', y.dish_name,
          'orders_count', y.cnt,
          'quantity_sold', y.qty
        ))
        from (
          select oi.dish_name,
                 count(distinct oi.order_id)::int as cnt,
                 coalesce(sum(oi.quantity), 0)::int as qty
          from public.order_items oi
          join public.orders o on o.id = oi.order_id
          where o.created_at >= (now() - (v_daily_days || ' days')::interval)
          group by oi.dish_name
          order by cnt desc
          limit 15
        ) y
      ), '[]'::jsonb),
    'peak_order_hours',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'hour', h,
          'count', c
        ) order by h)
        from (
          select extract(hour from o.created_at at time zone 'UTC')::int as h,
                 count(*)::int as c
          from public.orders o
          where o.created_at >= (now() - (v_hour_days || ' days')::interval)
          group by 1
          order by 1
        ) s
      ), '[]'::jsonb),
    'user_growth_by_day',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'date', d::text,
          'new_users', n
        ) order by d)
        from (
          select date_trunc('day', p.created_at)::date as d, count(*)::int as n
          from public.profiles p
          where p.created_at >= (current_date - (v_daily_days || ' days')::interval)
          group by 1
          order by 1
        ) s
      ), '[]'::jsonb),
    'application_status_pie',
      coalesce((
        select jsonb_object_agg(lower(trim(status::text)), cnt)
        from (
          select status, count(*)::int as cnt
          from public.chef_documents
          group by status
        ) q
      ), '{}'::jsonb),
    'most_active_customers',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'customer_id', z.customer_id,
          'name', z.nm,
          'order_count', z.cnt
        ) order by z.cnt desc)
        from (
          select o.customer_id,
                 coalesce(nullif(trim(max(o.customer_name)), ''), o.customer_id::text) as nm,
                 count(*)::int as cnt
          from public.orders o
          where o.customer_id is not null
            and o.created_at >= (now() - (v_daily_days || ' days')::interval)
          group by o.customer_id
          order by cnt desc
          limit 15
        ) z
      ), '[]'::jsonb),
    'highest_rated_cooks',
      '[]'::jsonb
  );
end;
$$;

comment on function public.get_admin_analytics_bundle(integer, integer, integer) is
  'Admin-only JSON: orders/revenue series, rankings, peak hours, user signups, document status counts. Extend highest_rated_cooks when a ratings table exists.';

grant execute on function public.get_admin_analytics_bundle(integer, integer, integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Alerts summary for “Attention needed”
-- -----------------------------------------------------------------------------
create or replace function public.get_admin_alerts_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expired_docs int := 0;
  v_pending_apps int := 0;
  v_frozen int := 0;
  v_reported int := 0;
  v_chats_review int := 0;
  v_stuck_orders int := 0;
begin
  perform public.ensure_admin();

  if to_regclass('public.chef_documents') is not null then
    select count(*) into v_expired_docs
    from public.chef_documents
    where expiry_date is not null and expiry_date::date < current_date
      and lower(trim(status::text)) = 'approved';

    select count(*) into v_pending_apps
    from public.chef_documents where lower(trim(status::text)) = 'pending';
  end if;

  select count(distinct p.id) into v_frozen
  from public.profiles p
  left join public.chef_profiles cp on cp.id = p.id
  where p.is_blocked = true
     or (cp.freeze_until is not null and cp.freeze_until > now());

  if to_regclass('public.reel_reports') is not null then
    select count(*) into v_reported
    from public.reel_reports
    where coalesce(lower(trim(status::text)), 'open') in ('open', 'pending', 'new');
  end if;

  if to_regclass('public.support_tickets') is not null then
    select count(*) into v_chats_review
    from public.support_tickets where status in ('open', 'in_progress');
  else
    v_chats_review := 0;
  end if;

  select count(*) into v_stuck_orders
  from public.orders
  where status in ('paid_waiting_acceptance','pending','accepted','preparing','ready')
    and updated_at < now() - interval '2 hours';

  return jsonb_build_object(
    'expired_documents', v_expired_docs,
    'pending_applications', v_pending_apps,
    'frozen_accounts', v_frozen,
    'reported_reels', v_reported,
    'chats_needing_review', v_chats_review,
    'orders_stuck', v_stuck_orders
  );
end;
$$;

grant execute on function public.get_admin_alerts_summary() to authenticated;

-- -----------------------------------------------------------------------------
-- 4) User detail bundle (profile + optional auth email + cook row + order stats)
-- -----------------------------------------------------------------------------
create or replace function public.get_admin_user_detail(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_profile jsonb;
  v_email text;
  v_chef jsonb;
  v_orders_total int := 0;
  v_orders_completed int := 0;
  v_orders_cancelled int := 0;
  v_revenue numeric := 0;
  v_favs jsonb := '[]'::jsonb;
  v_conv int := 0;
  v_last timestamptz;
  v_cook_pending int := 0;
  v_cook_active int := 0;
begin
  perform public.ensure_admin();

  select to_jsonb(t) into v_profile
  from public.profiles t
  where t.id = p_user_id;

  if v_profile is null then
    return jsonb_build_object('error', 'not_found');
  end if;

  v_role := lower(trim(v_profile->>'role'));

  select u.email into v_email
  from auth.users u
  where u.id = p_user_id;

  if v_role = 'chef' then
    select to_jsonb(cp.*) into v_chef
    from public.chef_profiles cp
    where cp.id = p_user_id;
  end if;

  if v_role = 'customer' then
    select
      count(*)::int,
      count(*) filter (where status = 'completed')::int,
      count(*) filter (where status::text like 'cancelled%' or status in ('rejected','expired'))::int,
      coalesce(sum(total_amount) filter (where status = 'completed'), 0)
    into v_orders_total, v_orders_completed, v_orders_cancelled, v_revenue
    from public.orders
    where customer_id = p_user_id;
  elsif v_role = 'chef' then
    select
      count(*)::int,
      count(*) filter (where status = 'completed')::int,
      count(*) filter (where status::text like 'cancelled%' or status in ('rejected','expired'))::int,
      coalesce(sum(total_amount) filter (where status = 'completed'), 0)
    into v_orders_total, v_orders_completed, v_orders_cancelled, v_revenue
    from public.orders
    where chef_id = p_user_id;

    select
      count(*) filter (where status = 'pending')::int,
      count(*) filter (where status in ('accepted','preparing','ready'))::int
    into v_cook_pending, v_cook_active
    from public.orders
    where chef_id = p_user_id;
  end if;

  if v_role = 'customer' then
    select coalesce((
      select jsonb_agg(jsonb_build_object(
        'chef_id', qq.chef_id,
        'name', coalesce(nullif(trim(qq.mx), ''), qq.chef_id::text),
        'order_count', qq.cnt
      ))
      from (
        select o.chef_id, max(o.chef_name) as mx, count(*)::int as cnt
        from public.orders o
        where o.customer_id = p_user_id and o.chef_id is not null
        group by o.chef_id
        order by cnt desc
        limit 10
      ) qq
    ), '[]'::jsonb) into v_favs;
  end if;

  if to_regclass('public.conversations') is not null then
    select count(*)::int into v_conv
    from public.conversations c
    where c.customer_id = p_user_id or c.chef_id = p_user_id;
  end if;

  select max(o.updated_at) into v_last
  from public.orders o
  where (v_role = 'customer' and o.customer_id = p_user_id)
     or (v_role = 'chef' and o.chef_id = p_user_id);

  return jsonb_build_object(
    'profile', v_profile,
    'email', coalesce(v_email, ''),
    'chef_profile', v_chef,
    'order_stats', jsonb_build_object(
      'total', v_orders_total,
      'completed', v_orders_completed,
      'cancelled', v_orders_cancelled,
      'completed_revenue', v_revenue
    ),
    'cook_open_orders', case
      when v_role = 'chef' then jsonb_build_object(
        'pending', v_cook_pending,
        'active', v_cook_active
      )
      else null::jsonb
    end,
    'favorite_cooks', v_favs,
    'conversation_count', v_conv,
    'last_order_activity_at', to_jsonb(v_last)
  );
end;
$$;

grant execute on function public.get_admin_user_detail(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) Cook discipline (admin)
-- -----------------------------------------------------------------------------
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

create or replace function public.admin_cook_increment_warning(p_cook_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v int;
begin
  perform public.ensure_admin();
  update public.chef_profiles
  set warning_count = coalesce(warning_count, 0) + 1
  where id = p_cook_id
  returning warning_count into v;
  return coalesce(v, 0);
end;
$$;

grant execute on function public.admin_cook_increment_warning(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Optional: reel moderation reports table (uncomment if you need counts > 0)
-- -----------------------------------------------------------------------------
-- create table if not exists public.reel_reports (
--   id uuid primary key default gen_random_uuid(),
--   reel_id uuid not null references public.reels(id) on delete cascade,
--   reporter_id uuid references auth.users(id),
--   reason text,
--   status text not null default 'open',
--   created_at timestamptz not null default now()
-- );
