-- ============================================================
-- Fix: infinite recursion in RLS policies on "profiles"
-- Run this ENTIRE script in Supabase → SQL Editor → New query → Run
-- ============================================================

-- ----------------------------------------------------------------
-- Compatibility hotfix:
-- Some legacy policies/functions still reference profiles.is_blocked.
-- Add a safe compatibility column to unblock login immediately.
-- ----------------------------------------------------------------
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_blocked boolean NOT NULL DEFAULT false;

-- Step 1: Turn OFF RLS so we can safely drop policies
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop EVERY policy on profiles (no matter the name)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles' AND schemaname = 'public')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', r.policyname);
  END LOOP;
END $$;

-- Step 3: Turn RLS back ON
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Step 4: Create ONLY simple policies (no SELECT from profiles = no recursion)
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Done. Try sign up / login again from the app.
-- If you still see recursion: check Database → Triggers for "profiles" and
-- ensure no trigger does SELECT/UPDATE on profiles itself.

-- ============================================================
-- Orders RLS (Cook must update own orders)
-- ============================================================
-- Enable RLS if not enabled:
-- ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
--
-- Cook can SELECT own orders:
-- CREATE POLICY "orders_select_chef"
--   ON public.orders FOR SELECT
--   USING (auth.uid() = chef_id);
--
-- Cook can UPDATE own orders (accept/reject/status changes):
-- CREATE POLICY "orders_update_chef"
--   ON public.orders FOR UPDATE
--   USING (auth.uid() = chef_id)
--   WITH CHECK (auth.uid() = chef_id);
--
-- Chef profiles: cook can update own is_online:
-- ALTER TABLE public.chef_profiles ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "chef_profiles_update_own"
--   ON public.chef_profiles FOR UPDATE
--   USING (auth.uid() = id)
--   WITH CHECK (auth.uid() = id);

-- Cook can UPDATE own orders (accept/reject/status changes):
-- Adds the policy even if it doesn't exist yet.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'orders'
      AND schemaname = 'public'
      AND policyname = 'Cook updates own orders'
  ) THEN
    CREATE POLICY "Cook updates own orders"
      ON public.orders
      FOR UPDATE
      USING (chef_id = auth.uid());
  END IF;
END $$;
