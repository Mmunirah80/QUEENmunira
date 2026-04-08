-- ============================================================
-- Reels visibility — independent of cook online / vacation / hours
--
-- Problem: reels_select_visibility (supabase_rls_orders_reels_approved_chef.sql)
--   hid ALL reels from other users when chef_profiles no longer matched
--   (approval_status != 'approved' OR suspended), so reels "vanished" whenever
--   account standing changed — unrelated to storefront availability.
--
-- Fix: SELECT uses only reel-row flags:
--   • is_active = true (default true for existing rows)
--   • deleted_at IS NULL (soft delete; hard DELETE still allowed)
--   • is_hidden = false (admin moderation; from supabase_admin_moderation_extensions.sql)
--
-- Chef / admin / owner still see their own rows via OR chef_id = auth.uid().
--
-- Run in Supabase SQL editor AFTER:
--   supabase_reels_system.sql
--   supabase_rls_orders_reels_approved_chef.sql (or at least after reels RLS exists)
--   supabase_admin_moderation_extensions.sql (for is_hidden column; optional COALESCE below)
-- ============================================================

ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

-- Align with supabase_admin_moderation_extensions.sql (safe if already applied)
ALTER TABLE public.reels
  ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.reels.is_active IS
  'When false, reel is hidden from public feeds (owner/admin still see via RLS).';

COMMENT ON COLUMN public.reels.deleted_at IS
  'Soft-delete timestamp; NULL means not deleted. Public feeds exclude non-null.';

CREATE INDEX IF NOT EXISTS idx_reels_public_lookup
  ON public.reels (is_active, deleted_at, created_at DESC);

-- Replace visibility policy (drops chef_profiles dependency for SELECT)
DROP POLICY IF EXISTS reels_select_visibility ON public.reels;
DROP POLICY IF EXISTS reels_select_public ON public.reels;
DROP POLICY IF EXISTS reels_select_all ON public.reels;

CREATE POLICY reels_select_public
  ON public.reels FOR SELECT
  TO authenticated
  USING (
    public.is_admin()
    OR auth.uid() = chef_id
    OR (
      COALESCE(is_active, true) = true
      AND deleted_at IS NULL
      AND COALESCE(is_hidden, false) = false
    )
  );

COMMENT ON POLICY reels_select_public ON public.reels IS
  'Public feed: active, not soft-deleted, not admin-hidden. No chef online/vacation/hours check.';
