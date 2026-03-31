-- ============================================================
-- NAHAM — Enforce approved, non-suspended chefs for marketplace orders + public reels
--
-- Run in Supabase SQL Editor after:
--   supabase_rls_authorization_hardening.sql
--   supabase_reels_system.sql
--
-- Fixes:
--   • Customers could INSERT orders for any chef_id (bypassing browse filters).
--   • Chefs could INSERT reels while pending/suspended; all users saw them (SELECT was open).
-- ============================================================

-- ─── Orders: customer may only create orders targeting an approved ONLINE storefront ───

DROP POLICY IF EXISTS orders_insert_customer ON public.orders;

CREATE POLICY orders_insert_customer
  ON public.orders FOR INSERT
  TO authenticated
  WITH CHECK (
    public.auth_is_active_user ()
    AND public.auth_role () = 'customer'
    AND customer_id = auth.uid ()
    AND EXISTS (
      SELECT 1
      FROM public.chef_profiles cp
      WHERE cp.id = orders.chef_id
        AND cp.approval_status = 'approved'
        AND COALESCE (cp.suspended, false) = false
        AND COALESCE (cp.is_online, false) = true
    )
  );

COMMENT ON POLICY orders_insert_customer ON public.orders IS
  'Customers may only place orders with chefs who are approved, not suspended, and online.';

-- ─── Reels: insert only if chef is approved + not suspended ───
-- Idempotent: safe to re-run after a previous apply (42710 if missing DROP).

DROP POLICY IF EXISTS reels_insert_approved_chef ON public.reels;
DROP POLICY IF EXISTS reels_insert_own ON public.reels;

CREATE POLICY reels_insert_approved_chef
  ON public.reels FOR INSERT
  TO authenticated
  WITH CHECK (
    chef_id = auth.uid ()
    AND EXISTS (
      SELECT 1
      FROM public.chef_profiles cp
      WHERE cp.id = auth.uid ()
        AND cp.approval_status = 'approved'
        AND COALESCE (cp.suspended, false) = false
    )
  );

-- ─── Reels: feed visible to others only for approved chefs; owner + admin always ───

DROP POLICY IF EXISTS reels_select_visibility ON public.reels;
DROP POLICY IF EXISTS reels_select_all ON public.reels;

CREATE POLICY reels_select_visibility
  ON public.reels FOR SELECT
  TO authenticated
  USING (
    public.is_admin ()
    OR auth.uid () = chef_id
    OR EXISTS (
      SELECT 1
      FROM public.chef_profiles cp
      WHERE cp.id = reels.chef_id
        AND cp.approval_status = 'approved'
        AND COALESCE (cp.suspended, false) = false
    )
  );
