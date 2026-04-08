-- ============================================================
-- NAHAM — MARKETPLACE INTEGRITY (FINAL CONSOLIDATION) v1
-- ============================================================
-- Run in Supabase SQL Editor AFTER backup, on top of existing schema.
--
-- Replaces / supersedes conflicting definitions from:
--   • supabase_rls_authorization_hardening.sql (weak orders_insert_customer)
--   • supabase_rls_orders_reels_approved_chef.sql (orders_insert_customer)
--   • supabase_cook_freeze_policy_v1.sql (orders_insert_customer)
--   • supabase_orders_unified_cancel_v1.sql (is_valid_order_transition +
--     transition_order_status without graph validation)
--   • supabase_order_state_machine.sql (older transition overloads; trigger
--     function must stay compatible with unified enum labels)
--
-- FINAL RULES (this file is authoritative for new deploys):
-- 1) Customer INSERT on orders: one policy only; chef must pass
--    chef_profile_allows_customer_order(chef_id) — approved OR full_access
--    with documents_operational_ok, online, not suspended, not frozen,
--    not on vacation, within working hours (JSON + legacy columns, kitchen_timezone),
--    chef profile not blocked in public.profiles.
-- 2) Order status changes: transition_order_status enforces
--    is_valid_order_transition before UPDATE; BEFORE UPDATE trigger enforces
--    the same graph for any direct row UPDATE (service_role jobs use
--    auth.uid() IS NULL and must only issue valid transitions).
-- 3) RLS UPDATE on orders: authenticated admins only (chefs/customers use RPC).
-- 4) Cook reject note: optional p_rejection_reason on transition_order_status
--    (no second PATCH from the app).
--
-- Flutter: keep in sync with chef_profile_allows_customer_order + batch RPC
-- chef_orderable_for_customers_batch (see customer_browse_supabase_datasource).
-- ============================================================

-- ─── Schema safety (older DBs) ───────────────────────────────────────────
ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS documents_operational_ok boolean NOT NULL DEFAULT false;

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS access_level text;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS rejection_reason text;

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS working_hours jsonb;

ALTER TABLE public.chef_profiles
  ADD COLUMN IF NOT EXISTS kitchen_timezone text DEFAULT 'UTC';

-- ─── 1a) Time parser (HH:mm / H:mm on legacy columns and JSON open/close) ─
CREATE OR REPLACE FUNCTION public._inspection_parse_hhmm_to_minutes (p_text text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  t text := trim(coalesce(p_text, ''));
  p int;
  h int;
  m int;
BEGIN
  IF t = '' THEN
    RETURN NULL;
  END IF;
  p := position(':' IN t);
  IF p < 1 THEN
    RETURN NULL;
  END IF;
  h := (substring(t FROM 1 FOR p - 1))::integer;
  m := (substring(t FROM p + 1 FOR 2))::integer;
  IF h IS NULL OR m IS NULL THEN
    RETURN NULL;
  END IF;
  IF h < 0 OR h > 23 OR m < 0 OR m > 59 THEN
    RETURN NULL;
  END IF;
  RETURN h * 60 + m;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._inspection_parse_hhmm_to_minutes (p_t time without time zone)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT public._inspection_parse_hhmm_to_minutes (p_t::text);
$$;

-- ─── 1b) Working hours (chef local wall clock via kitchen_timezone) ───────
-- Matches Flutter isWithinWorkingHours: {} => closed; JSON per-day open/close;
-- enabled=false => closed; unknown JSON keys try Mon/mon/1/Monday aliases;
-- JSON present but no today slot => legacy columns; no schedule => open (legacy toggle-only).
CREATE OR REPLACE FUNCTION public.chef_is_within_working_hours_now (p_chef_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cp record;
  v_tz text;
  v_local timestamp;
  v_now_min int;
  v_isodow int;
  v_short text;
  v_long text;
  v_keys text[];
  k text;
  v_day jsonb;
  v_open text;
  v_close text;
  v_a int;
  v_b int;
  v_s int;
  v_e int;
BEGIN
  SELECT
    working_hours,
    working_hours_start,
    working_hours_end,
    kitchen_timezone
  INTO cp
  FROM
    public.chef_profiles
  WHERE
    id = p_chef_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  v_tz := nullif(trim(coalesce(cp.kitchen_timezone, '')), '');
  IF v_tz IS NULL THEN
    v_tz := 'UTC';
  END IF;

  v_local := timezone(v_tz, now());
  v_now_min :=
    extract(hour FROM v_local)::integer * 60 + extract(minute FROM v_local)::integer;
  v_isodow := extract(isodow FROM v_local)::integer;

  v_short := (ARRAY['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])[v_isodow];
  v_long := (
    ARRAY[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ]
  )[v_isodow];
  v_keys := ARRAY[
    v_short,
    lower(v_short),
    upper(v_short),
    v_isodow::text,
    v_long,
    lower(v_long),
    upper(v_long)
  ];

  IF cp.working_hours IS NOT NULL AND cp.working_hours = '{}'::jsonb THEN
    RETURN false;
  END IF;

  IF cp.working_hours IS NOT NULL AND jsonb_typeof(cp.working_hours) = 'object'
  AND cp.working_hours <> '{}'::jsonb THEN
    v_day := NULL;
    FOREACH k IN ARRAY v_keys LOOP
      IF cp.working_hours ? k THEN
        v_day := cp.working_hours -> k;
        IF v_day IS NOT NULL AND jsonb_typeof(v_day) = 'object' THEN
          EXIT;
        END IF;
      END IF;
    END LOOP;

    IF v_day IS NOT NULL AND jsonb_typeof(v_day) = 'object' THEN
      IF v_day ? 'enabled' THEN
        IF (v_day -> 'enabled') = 'false'::jsonb OR lower(trim(coalesce(v_day ->> 'enabled', ''))) IN ('false', '0', 'no') THEN
          RETURN false;
        END IF;
      END IF;
      v_open := v_day ->> 'open';
      v_close := v_day ->> 'close';
      IF v_open IS NOT NULL AND v_close IS NOT NULL AND length(trim(v_open)) > 0 AND length(trim(v_close)) > 0 THEN
        v_a := public._inspection_parse_hhmm_to_minutes(v_open);
        v_b := public._inspection_parse_hhmm_to_minutes(v_close);
        IF v_a IS NULL OR v_b IS NULL THEN
          RETURN false;
        END IF;
        IF v_b >= v_a THEN
          RETURN v_now_min >= v_a AND v_now_min <= v_b;
        ELSE
          RETURN v_now_min >= v_a OR v_now_min <= v_b;
        END IF;
      END IF;
    END IF;

    v_s := public._inspection_parse_hhmm_to_minutes(cp.working_hours_start::text);
    v_e := public._inspection_parse_hhmm_to_minutes(cp.working_hours_end::text);
    IF v_s IS NOT NULL AND v_e IS NOT NULL THEN
      IF v_e >= v_s THEN
        RETURN v_now_min >= v_s AND v_now_min <= v_e;
      ELSE
        RETURN v_now_min >= v_s OR v_now_min <= v_e;
      END IF;
    END IF;
    RETURN false;
  END IF;

  v_s := public._inspection_parse_hhmm_to_minutes(cp.working_hours_start::text);
  v_e := public._inspection_parse_hhmm_to_minutes(cp.working_hours_end::text);
  IF v_s IS NULL OR v_e IS NULL THEN
    RETURN true;
  END IF;
  IF v_e >= v_s THEN
    RETURN v_now_min >= v_s AND v_now_min <= v_e;
  ELSE
    RETURN v_now_min >= v_s OR v_now_min <= v_e;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.chef_is_within_working_hours_now (uuid) IS
  'True if current local time (kitchen_timezone) is inside configured working_hours JSON or legacy start/end. SECURITY DEFINER for use from RLS.';

REVOKE ALL ON FUNCTION public.chef_is_within_working_hours_now (uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chef_is_within_working_hours_now (uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chef_is_within_working_hours_now (uuid) TO service_role;

-- ─── 1c) Single source of truth: chef may receive a new customer order ─────
CREATE OR REPLACE FUNCTION public.chef_profile_allows_customer_order (p_chef_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT
      1
    FROM
      public.chef_profiles cp
    WHERE
      cp.id = p_chef_id
      AND COALESCE(cp.suspended, FALSE) = FALSE
      AND COALESCE(cp.is_online, FALSE) = TRUE
      AND (cp.freeze_until IS NULL OR cp.freeze_until <= now())
      AND COALESCE(cp.vacation_mode, FALSE) = FALSE
      AND NOT (
        cp.vacation_start IS NOT NULL
        AND cp.vacation_end IS NOT NULL
        AND CURRENT_DATE BETWEEN cp.vacation_start::date AND cp.vacation_end::date
      )
      AND (
        (
          lower(trim(coalesce(cp.access_level, ''))) = 'full_access'
          AND COALESCE(cp.documents_operational_ok, FALSE) = TRUE
        )
        OR lower(trim(coalesce(cp.approval_status, ''))) = 'approved'
      )
  ) THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT
      1
    FROM
      public.profiles pr
    WHERE
      pr.id = p_chef_id
      AND COALESCE(pr.is_blocked, FALSE) = FALSE
  ) THEN
    RETURN false;
  END IF;

  RETURN public.chef_is_within_working_hours_now (p_chef_id);
END;
$$;

COMMENT ON FUNCTION public.chef_profile_allows_customer_order (uuid) IS
  'True when this chef may receive a new marketplace order: account gate + blocked check + chef_is_within_working_hours_now. Used by orders_insert_customer_marketplace_final.';

REVOKE ALL ON FUNCTION public.chef_profile_allows_customer_order (uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chef_profile_allows_customer_order (uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chef_profile_allows_customer_order (uuid) TO service_role;

-- Batch for customer UI (one round-trip)
CREATE OR REPLACE FUNCTION public.chef_orderable_for_customers_batch (p_chef_ids uuid[])
RETURNS TABLE (
  chef_id uuid,
  ok boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id AS chef_id,
    public.chef_profile_allows_customer_order (u.id) AS ok
  FROM
    unnest(coalesce(p_chef_ids, array[]::uuid[])) AS u(id);
$$;

COMMENT ON FUNCTION public.chef_orderable_for_customers_batch (uuid[]) IS
  'Per-chef result of chef_profile_allows_customer_order for customer browse/checkout.';

REVOKE ALL ON FUNCTION public.chef_orderable_for_customers_batch (uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chef_orderable_for_customers_batch (uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chef_orderable_for_customers_batch (uuid[]) TO service_role;

-- ─── 2) Transition graph (aligned with unified cancel + legacy enum labels) ─
CREATE OR REPLACE FUNCTION public.is_valid_order_transition (p_old text, p_new text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN trim(coalesce(p_old, '')) = trim(coalesce(p_new, '')) THEN TRUE
    WHEN trim(coalesce(p_old, '')) IN ('pending', 'paid_waiting_acceptance')
      AND trim(coalesce(p_new, '')) IN (
        'accepted',
        'cancelled',
        'cancelled_by_customer',
        'cancelled_by_cook',
        'cancelled_by_system',
        'cancelled_payment_failed',
        'expired'
      ) THEN TRUE
    WHEN trim(coalesce(p_old, '')) = 'accepted'
      AND trim(coalesce(p_new, '')) IN (
        'preparing',
        'cancelled',
        'cancelled_by_cook'
      ) THEN TRUE
    WHEN trim(coalesce(p_old, '')) IN ('preparing', 'cooking', 'in_progress')
      AND trim(coalesce(p_new, '')) IN (
        'ready',
        'cancelled',
        'cancelled_by_cook'
      ) THEN TRUE
    WHEN trim(coalesce(p_old, '')) = 'ready'
      AND trim(coalesce(p_new, '')) IN (
        'completed',
        'cancelled',
        'cancelled_by_cook'
      ) THEN TRUE
    ELSE FALSE
  END;
$$;

-- ─── 3) Trigger: block invalid direct UPDATEs (RPC also validates) ───────
CREATE OR REPLACE FUNCTION public.orders_enforce_state_machine ()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;
  IF NOT public.is_valid_order_transition (OLD.status::text, NEW.status::text) THEN
    RAISE EXCEPTION 'Invalid order status transition: % -> %', OLD.status, NEW.status;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_state_machine ON public.orders;

CREATE TRIGGER trg_orders_state_machine
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE PROCEDURE public.orders_enforce_state_machine ();

COMMENT ON FUNCTION public.orders_enforce_state_machine () IS
  'Rejects any illegal orders.status change (RPC, REST, or service_role) unless OLD.status = NEW.status.';

-- ─── 4) transition_order_status: validate graph + optional reject note ─────
DROP FUNCTION IF EXISTS public.transition_order_status (uuid, text, timestamptz, text, boolean, text);

DROP FUNCTION IF EXISTS public.transition_order_status (uuid, text, timestamptz, text, boolean);

DROP FUNCTION IF EXISTS public.transition_order_status (uuid, text, timestamptz);

DROP FUNCTION IF EXISTS public.transition_order_status (uuid, text);

CREATE OR REPLACE FUNCTION public.transition_order_status (
  order_id uuid,
  new_status text,
  expected_updated_at timestamptz DEFAULT NULL,
  cancel_reason text DEFAULT NULL,
  customer_system_cancel boolean DEFAULT FALSE,
  p_rejection_reason text DEFAULT NULL
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.orders%rowtype;
  v_old_status text;
  v_new text := trim(coalesce(new_status, ''));
  v_rej text := nullif(left(trim(coalesce(p_rejection_reason, '')), 2000), '');
BEGIN
  IF v_new = '' THEN
    RAISE EXCEPTION 'new_status is required';
  END IF;

  SELECT
    * INTO v_order
  FROM
    public.orders
  WHERE
    id = order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF expected_updated_at IS NOT NULL AND v_order.updated_at IS DISTINCT FROM expected_updated_at THEN
    RAISE EXCEPTION 'Order was updated by another process';
  END IF;

  v_old_status := v_order.status::text;

  IF v_new = 'cancelled' THEN
    IF cancel_reason IS NULL OR trim(cancel_reason) = '' THEN
      RAISE EXCEPTION 'cancelled requires cancel_reason';
    END IF;
    IF trim(cancel_reason) NOT IN (
      'cook_rejected',
      'system_cancelled_frozen',
      'system_cancelled_blocked'
    ) THEN
      RAISE EXCEPTION 'invalid cancel_reason';
    END IF;
  END IF;

  -- Actor authorization (unchanged semantics from unified cancel)
  IF auth.uid () = v_order.customer_id THEN
    IF NOT (
      v_old_status IN ('pending', 'paid_waiting_acceptance')
      AND v_new = 'cancelled'
      AND trim(coalesce(cancel_reason, '')) = 'system_cancelled_frozen'
      AND customer_system_cancel IS TRUE
    ) THEN
      RAISE EXCEPTION 'Customer is not allowed to perform this transition';
    END IF;
  ELSIF auth.uid () = v_order.chef_id THEN
    IF v_new = 'expired' THEN
      IF v_old_status NOT IN ('pending', 'paid_waiting_acceptance') THEN
        RAISE EXCEPTION 'Chef is not allowed to perform this transition';
      END IF;
    ELSIF v_new = 'cancelled' THEN
      IF trim(coalesce(cancel_reason, '')) = 'cook_rejected' THEN
        NULL;
      ELSIF trim(coalesce(cancel_reason, '')) = 'system_cancelled_frozen'
      AND v_old_status IN ('pending', 'paid_waiting_acceptance') THEN
        NULL;
      ELSE
        RAISE EXCEPTION 'Chef is not allowed to perform this transition';
      END IF;
    ELSIF v_new NOT IN (
      'accepted',
      'preparing',
      'ready',
      'completed',
      'cancelled_by_cook',
      'cancelled',
      'expired'
    ) THEN
      RAISE EXCEPTION 'Chef is not allowed to perform this transition';
    END IF;
  ELSE
    IF NOT EXISTS (
      SELECT
        1
      FROM
        public.profiles p
      WHERE
        p.id = auth.uid ()
        AND p.role = 'admin'
    ) THEN
      RAISE EXCEPTION 'Not authorized to transition this order';
    END IF;
  END IF;

  IF NOT public.is_valid_order_transition (v_old_status, v_new) THEN
    RAISE EXCEPTION 'Invalid order status transition: % -> %', v_old_status, v_new;
  END IF;

  UPDATE public.orders o
  SET
    status = v_new::public.order_status,
    cancel_reason = CASE
      WHEN v_new = 'cancelled' THEN trim(cancel_reason)
      ELSE NULL
    END,
    rejection_reason = CASE
      WHEN v_new = 'cancelled'
      AND trim(coalesce(cancel_reason, '')) = 'cook_rejected' THEN
        v_rej
      ELSE
        o.rejection_reason
    END,
    updated_at = now()
  WHERE
    o.id = order_id
  RETURNING
    * INTO v_order;

  INSERT INTO public.order_status_events (
    order_id,
    event_type,
    actor_id,
    from_status,
    to_status
  )
  VALUES (
    order_id,
    'status_transition',
    auth.uid (),
    v_old_status,
    v_new
  );

  -- Idempotent restore (order_status_events.stock_restored): any cancel/expire from an active row.
  IF v_new IN (
    'cancelled',
    'cancelled_by_customer',
    'cancelled_by_cook',
    'expired'
  )
  AND v_old_status NOT IN (
    'completed',
    'cancelled',
    'cancelled_by_customer',
    'cancelled_by_system',
    'cancelled_payment_failed',
    'expired',
    'rejected'
  ) THEN
    PERFORM public.restore_order_stock_once (order_id);
  END IF;

  RETURN v_order;
END;
$$;

REVOKE ALL ON FUNCTION public.transition_order_status (uuid, text, timestamptz, text, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transition_order_status (uuid, text, timestamptz, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_order_status (uuid, text, timestamptz, text, boolean, text) TO service_role;

-- ─── 5) RLS: ONE insert policy, tight UPDATE (admin only for authenticated) ─
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS orders_insert_customer ON public.orders;
DROP POLICY IF EXISTS orders_insert_customer_marketplace_final ON public.orders;

CREATE POLICY orders_insert_customer_marketplace_final ON public.orders
  FOR INSERT TO authenticated
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'customer'
    AND customer_id = auth.uid ()
    AND public.chef_profile_allows_customer_order (chef_id)
  );

COMMENT ON POLICY orders_insert_customer_marketplace_final ON public.orders IS
  'Single authoritative customer insert gate: self customer_id + chef_profile_allows_customer_order(chef_id), including working hours in SQL (kitchen_timezone).';

DROP POLICY IF EXISTS orders_update_parties ON public.orders;
DROP POLICY IF EXISTS orders_update_admin ON public.orders;
DROP POLICY IF EXISTS orders_update_admin_only ON public.orders;

CREATE POLICY orders_update_admin_only ON public.orders
  FOR UPDATE TO authenticated
  USING (public.is_admin ())
  WITH CHECK (public.is_admin ());

COMMENT ON POLICY orders_update_admin_only ON public.orders IS
  'Only admins may PATCH orders directly; chefs/customers use transition_order_status (SECURITY DEFINER).';

-- SELECT / DELETE: keep compatible with supabase_rls_authorization_hardening if present
-- (do not drop orders_select_parties / orders_delete_admin here).
