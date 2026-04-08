-- ============================================================
-- NAHAM — Unified order cancellation (single status + cancel_reason)
-- ============================================================
-- Run in Supabase SQL Editor after backup.
--
-- Business rules:
--   • Terminal cancel uses orders.status = 'cancelled' only.
--   • orders.cancel_reason ∈ { cook_rejected, system_cancelled_frozen, system_cancelled_blocked }
--   • Customers cannot cancel for convenience; they may only trigger system cancels via
--     payment-failure rollback or acceptance timeout (both → system_cancelled_frozen).
--   • Cook decline → cook_rejected. Freeze / enforcement → system_cancelled_frozen.
--   • Blocked chef → system_cancelled_blocked (pending orders voided).
--
-- Requires: public.order_status enum on orders.status (existing app migrations).
-- ============================================================

BEGIN;

-- 1) Enum label -----------------------------------------------------------
DO $$
BEGIN
  ALTER TYPE public.order_status ADD VALUE 'cancelled';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 2) Column + constraints -------------------------------------------------
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cancel_reason text;

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_cancel_reason_allowed;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_cancel_reason_allowed
  CHECK (
    cancel_reason IS NULL
    OR cancel_reason IN (
      'cook_rejected',
      'system_cancelled_frozen',
      'system_cancelled_blocked'
    )
  );

-- Old CHECK constraints may omit `cancelled` or require cancel_reason only after unified status;
-- drop before rewriting rows so UPDATE ... status = 'cancelled' succeeds.
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_status_allowed_values;

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_cancel_reason_when_cancelled;

-- 3) Backfill legacy terminal rows (keep old enum values until rewritten)
UPDATE public.orders o
SET
  cancel_reason = CASE o.status::text
    WHEN 'cancelled_by_cook' THEN 'cook_rejected'
    WHEN 'cancelled_by_system' THEN 'system_cancelled_frozen'
    WHEN 'cancelled_by_customer' THEN 'system_cancelled_frozen'
    WHEN 'cancelled_payment_failed' THEN 'system_cancelled_frozen'
    WHEN 'expired' THEN 'system_cancelled_frozen'
    WHEN 'rejected' THEN 'cook_rejected'
    ELSE o.cancel_reason
  END
WHERE o.status::text IN (
  'cancelled_by_cook',
  'cancelled_by_system',
  'cancelled_by_customer',
  'cancelled_payment_failed',
  'expired',
  'rejected'
);

UPDATE public.orders o
SET status = 'cancelled'::public.order_status,
    updated_at = coalesce(o.updated_at, now())
WHERE o.status::text IN (
  'cancelled_by_cook',
  'cancelled_by_system',
  'cancelled_by_customer',
  'cancelled_payment_failed',
  'expired',
  'rejected'
);

-- 4) Allowed status CHECK (include unified cancelled + legacy reads)
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_status_allowed_values;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_status_allowed_values
  CHECK (
    status::text IN (
      'pending',
      'paid_waiting_acceptance',
      'accepted',
      'preparing',
      'ready',
      'completed',
      'cancelled',
      'cancelled_by_customer',
      'cancelled_by_cook',
      'cancelled_by_system',
      'cancelled_payment_failed',
      'expired',
      'rejected'
    )
  );

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_cancel_reason_when_cancelled;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_cancel_reason_when_cancelled
  CHECK (
    status::text <> 'cancelled'
    OR cancel_reason IS NOT NULL
  );

-- 5) State machine -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_valid_order_transition (p_old text, p_new text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_old = p_new THEN TRUE
    WHEN p_old IN ('pending', 'paid_waiting_acceptance') AND p_new IN (
      'accepted',
      'cancelled',
      'cancelled_by_customer',
      'cancelled_by_cook',
      'cancelled_by_system',
      'cancelled_payment_failed',
      'expired'
    ) THEN TRUE
    WHEN p_old = 'accepted' AND p_new IN ('preparing', 'cancelled', 'cancelled_by_cook') THEN TRUE
    WHEN p_old IN ('preparing', 'cooking', 'in_progress') AND p_new IN ('ready', 'cancelled', 'cancelled_by_cook') THEN TRUE
    WHEN p_old = 'ready' AND p_new IN ('completed', 'cancelled', 'cancelled_by_cook') THEN TRUE
    ELSE FALSE
  END;
$$;

-- 6) transition_order_status (single write path)
DROP FUNCTION IF EXISTS public.transition_order_status (uuid, text, timestamptz);
DROP FUNCTION IF EXISTS public.transition_order_status (uuid, text);
DROP FUNCTION IF EXISTS public.transition_order_status (uuid, text, timestamptz, text, boolean);

CREATE OR REPLACE FUNCTION public.transition_order_status (
  order_id uuid,
  new_status text,
  expected_updated_at timestamptz DEFAULT NULL,
  cancel_reason text DEFAULT NULL,
  customer_system_cancel boolean DEFAULT FALSE
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
BEGIN
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = order_id
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

  -- Customer: only automated system cancels (not cook reject).
  IF auth.uid() = v_order.customer_id THEN
    IF NOT (
      v_old_status IN ('pending', 'paid_waiting_acceptance')
      AND v_new = 'cancelled'
      AND trim(coalesce(cancel_reason, '')) = 'system_cancelled_frozen'
      AND customer_system_cancel IS TRUE
    ) THEN
      RAISE EXCEPTION 'Customer is not allowed to perform this transition';
    END IF;
  ELSIF auth.uid() = v_order.chef_id THEN
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
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role = 'admin'
    ) THEN
      RAISE EXCEPTION 'Not authorized to transition this order';
    END IF;
  END IF;

  UPDATE public.orders o
  SET
    status = v_new::public.order_status,
    cancel_reason = CASE
      WHEN v_new = 'cancelled' THEN trim(cancel_reason)
      ELSE NULL
    END,
    updated_at = now()
  WHERE o.id = order_id
  RETURNING * INTO v_order;

  INSERT INTO public.order_status_events (order_id, event_type, actor_id, from_status, to_status)
  VALUES (order_id, 'status_transition', auth.uid(), v_old_status, v_new);

  IF v_old_status IN ('pending', 'paid_waiting_acceptance')
     AND v_new IN (
       'cancelled',
       'cancelled_by_customer',
       'cancelled_by_cook',
       'expired'
     ) THEN
    PERFORM public.restore_order_stock_once (order_id);
  END IF;

  RETURN v_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.transition_order_status (uuid, text, timestamptz, text, boolean) TO authenticated;

-- 7) Batch expiry (cron) → unified cancelled + system_cancelled_frozen
CREATE OR REPLACE FUNCTION public.expire_stale_pending_orders ()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n int := 0;
  r record;
  v_old text;
BEGIN
  FOR r IN
    SELECT id, status::text AS st
    FROM public.orders
    WHERE status IN ('pending', 'paid_waiting_acceptance')
      AND created_at < (timezone('utc', now()) - interval '5 minutes')
    FOR UPDATE SKIP LOCKED
  LOOP
    v_old := r.st;

    UPDATE public.orders
    SET
      status = 'cancelled'::public.order_status,
      cancel_reason = 'system_cancelled_frozen',
      updated_at = now()
    WHERE id = r.id;

    INSERT INTO public.order_status_events (order_id, event_type, actor_id, from_status, to_status)
    VALUES (r.id, 'status_transition', NULL, v_old, 'cancelled');

    IF v_old IN ('pending', 'paid_waiting_acceptance') THEN
      PERFORM public.restore_order_stock_once (r.id);
    END IF;

    n := n + 1;
  END LOOP;

  RETURN n;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_stale_pending_orders () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expire_stale_pending_orders () TO service_role;

-- 8) Enforcement: pending orders when chef frozen (admin ladder)
CREATE OR REPLACE FUNCTION public.admin_chef_take_enforcement_action (p_cook_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_w int;
  v_fl int;
  v_until timestamptz;
  r record;
BEGIN
  PERFORM public.ensure_admin ();

  SELECT coalesce(warning_count, 0), coalesce(freeze_level, 0)
    INTO v_w, v_fl
  FROM public.chef_profiles
  WHERE id = p_cook_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'chef profile not found';
  END IF;

  IF v_w = 0 THEN
    UPDATE public.chef_profiles
    SET warning_count = 1
    WHERE id = p_cook_id;
    RETURN jsonb_build_object('action', 'warning', 'warning_count', 1);
  END IF;

  IF v_fl = 0 THEN
    v_until := (now() AT TIME ZONE 'utc') + interval '3 days';
    UPDATE public.chef_profiles
    SET
      freeze_until = v_until,
      freeze_started_at = now(),
      freeze_type = 'soft',
      freeze_level = 1,
      is_online = false
    WHERE id = p_cook_id;

    FOR r IN
      SELECT id
      FROM public.orders
      WHERE chef_id = p_cook_id
        AND status IN ('pending', 'paid_waiting_acceptance')
    LOOP
      UPDATE public.orders
      SET
        status = 'cancelled'::public.order_status,
        cancel_reason = 'system_cancelled_frozen',
        updated_at = now()
      WHERE id = r.id;
      PERFORM public.restore_order_stock_once (r.id);
    END LOOP;

    RETURN jsonb_build_object('action', 'freeze_3d', 'freeze_until', v_until, 'freeze_level', 1);
  END IF;

  IF v_fl = 1 THEN
    v_until := (now() AT TIME ZONE 'utc') + interval '7 days';
    UPDATE public.chef_profiles
    SET
      freeze_until = v_until,
      freeze_started_at = now(),
      freeze_level = 2,
      is_online = false
    WHERE id = p_cook_id;

    FOR r IN
      SELECT id
      FROM public.orders
      WHERE chef_id = p_cook_id
        AND status IN ('pending', 'paid_waiting_acceptance')
    LOOP
      UPDATE public.orders
      SET
        status = 'cancelled'::public.order_status,
        cancel_reason = 'system_cancelled_frozen',
        updated_at = now()
      WHERE id = r.id;
      PERFORM public.restore_order_stock_once (r.id);
    END LOOP;

    RETURN jsonb_build_object('action', 'freeze_7d', 'freeze_until', v_until, 'freeze_level', 2);
  END IF;

  IF v_fl = 2 THEN
    v_until := (now() AT TIME ZONE 'utc') + interval '14 days';
    UPDATE public.chef_profiles
    SET
      freeze_until = v_until,
      freeze_started_at = now(),
      freeze_level = 3,
      is_online = false
    WHERE id = p_cook_id;

    FOR r IN
      SELECT id
      FROM public.orders
      WHERE chef_id = p_cook_id
        AND status IN ('pending', 'paid_waiting_acceptance')
    LOOP
      UPDATE public.orders
      SET
        status = 'cancelled'::public.order_status,
        cancel_reason = 'system_cancelled_frozen',
        updated_at = now()
      WHERE id = r.id;
      PERFORM public.restore_order_stock_once (r.id);
    END LOOP;

    RETURN jsonb_build_object('action', 'freeze_14d', 'freeze_until', v_until, 'freeze_level', 3);
  END IF;

  IF v_fl = 3 THEN
    UPDATE public.profiles
    SET is_blocked = true
    WHERE id = p_cook_id;

    FOR r IN
      SELECT id
      FROM public.orders
      WHERE chef_id = p_cook_id
        AND status IN ('pending', 'paid_waiting_acceptance')
    LOOP
      UPDATE public.orders
      SET
        status = 'cancelled'::public.order_status,
        cancel_reason = 'system_cancelled_blocked',
        updated_at = now()
      WHERE id = r.id;
      PERFORM public.restore_order_stock_once (r.id);
    END LOOP;

    RETURN jsonb_build_object('action', 'blocked');
  END IF;

  RAISE EXCEPTION 'unexpected state warning_count=% freeze_level=%', v_w, v_fl;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_chef_take_enforcement_action (uuid) TO authenticated;

COMMIT;
