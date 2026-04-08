-- ============================================================
-- Reels SELECT — require approved, non-suspended, non-frozen chef for public rows
--
-- Problem: supabase_reels_visibility_independent.sql allowed any authenticated user to
--   SELECT reels that were is_active + not soft-deleted + not hidden, without checking
--   chef_profiles (so pending/suspended/frozen chefs' reels leaked to clients).
--
-- Fix: Keep owner + admin full access; for everyone else, require EXISTS chef_profiles
--   (approved, not suspended, freeze_until cleared) AND reel visibility flags.
--
-- Run AFTER: supabase_reels_visibility_independent.sql (needs is_active, deleted_at, is_hidden).
-- Requires: public.is_admin().
-- ============================================================

DROP POLICY IF EXISTS reels_select_public ON public.reels;

CREATE POLICY reels_select_public
  ON public.reels FOR SELECT
  TO authenticated
  USING (
    public.is_admin ()
    OR auth.uid () = chef_id
    OR (
      EXISTS (
        SELECT 1
        FROM public.chef_profiles cp
        WHERE cp.id = reels.chef_id
          AND cp.approval_status = 'approved'
          AND COALESCE (cp.suspended, false) = false
          AND (cp.freeze_until IS NULL OR cp.freeze_until <= now())
      )
      AND COALESCE (is_active, true) = true
      AND deleted_at IS NULL
      AND COALESCE (is_hidden, false) = false
    )
  );

COMMENT ON POLICY reels_select_public ON public.reels IS
  'Public: approved chef, not suspended, not frozen, reel active/not deleted/not hidden. Admin and owner bypass.';
