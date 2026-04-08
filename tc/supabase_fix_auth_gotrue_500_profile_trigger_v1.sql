-- =============================================================================
-- NAHAM — Fix GoTrue Auth 500: unexpected_failure / "Database error querying schema"
-- =============================================================================
-- Symptom: signUp / signInWithPassword returns 500; Flutter may show AuthException
-- with message containing "querying schema" or "unexpected_failure".
--
-- Root cause (typical): AFTER INSERT ON auth.users runs public.handle_new_user (or
-- similar) that INSERTs into public.profiles using wrong/missing columns (e.g.
-- profiles.email removed), bad casts to profiles.role, NOT NULL violations, or
-- other errors — PostgreSQL aborts the auth.users INSERT, so Auth returns 500.
--
-- This script (idempotent, production-safe):
--   1) Adds minimal profiles columns if missing (full_name, is_blocked).
--   2) Replaces public.handle_new_user: only inserts columns that actually exist
--      on public.profiles (never profiles.email); dynamic cast for role type;
--      ON CONFLICT (id) DO NOTHING; failures swallowed with WARNING so auth
--      user creation still commits.
--   3) Drops/recreates trigger on_auth_user_created.
--   4) NOTIFY pgrst, 'reload schema'.
--
-- Run in Supabase Dashboard → SQL Editor (or psql against the project DB).
-- If another trigger name is used, inspect:
--   SELECT tgname, pg_get_triggerdef(oid) FROM pg_trigger
--   WHERE tgrelid = 'auth.users'::regclass AND NOT tgisinternal;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Minimal schema safety (idempotent)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS is_blocked boolean NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- 2) handle_new_user — dynamic columns + safe role cast + non-fatal errors
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user ()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_name text;
  role_nsp text;
  role_name text;
  v_has_id boolean;
  v_has_full_name boolean;
  v_has_role_col boolean;
  v_has_is_blocked boolean;
  v_sql text;
BEGIN
  v_role := lower(trim(COALESCE(NEW.raw_user_meta_data ->> 'role', 'customer')));
  IF v_role = 'cook' THEN
    v_role := 'chef';
  END IF;
  IF v_role NOT IN ('customer', 'chef', 'admin') THEN
    v_role := 'customer';
  END IF;

  -- Display name: metadata only + local-part from auth email if present (no profiles.email).
  v_name := COALESCE(
    NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), ''),
    NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''),
    'User'
  );

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'profiles'
      AND c.column_name = 'id'
  ) INTO v_has_id;

  IF NOT v_has_id THEN
    RAISE WARNING 'handle_new_user: public.profiles.id missing; skip profile insert';
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = 'public' AND c.table_name = 'profiles' AND c.column_name = 'full_name'
  ) INTO v_has_full_name;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = 'public' AND c.table_name = 'profiles' AND c.column_name = 'role'
  ) INTO v_has_role_col;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = 'public' AND c.table_name = 'profiles' AND c.column_name = 'is_blocked'
  ) INTO v_has_is_blocked;

  IF NOT v_has_role_col THEN
    RAISE WARNING 'handle_new_user: public.profiles.role missing; skip profile insert';
    RETURN NEW;
  END IF;

  SELECT nt.nspname, t.typname
  INTO role_nsp, role_name
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_type t ON t.oid = a.atttypid
  JOIN pg_namespace nt ON nt.oid = t.typnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'profiles'
    AND a.attname = 'role'
    AND a.attnum > 0
    AND NOT a.attisdropped
  LIMIT 1;

  IF role_name IS NULL THEN
    RAISE WARNING 'handle_new_user: could not resolve type for public.profiles.role; skip profile insert';
    RETURN NEW;
  END IF;

  v_sql := 'INSERT INTO public.profiles (id';
  IF v_has_full_name THEN
    v_sql := v_sql || ', full_name';
  END IF;
  v_sql := v_sql || ', role';
  IF v_has_is_blocked THEN
    v_sql := v_sql || ', is_blocked';
  END IF;

  v_sql := v_sql || ') VALUES ($1';
  IF v_has_full_name THEN
    v_sql := v_sql || ', $2';
  END IF;
  v_sql := v_sql || format(', %L::%I.%I', v_role, role_nsp, role_name);
  IF v_has_is_blocked THEN
    IF v_has_full_name THEN
      v_sql := v_sql || ', $3';
    ELSE
      v_sql := v_sql || ', $2';
    END IF;
  END IF;

  v_sql := v_sql || ') ON CONFLICT (id) DO NOTHING';

  BEGIN
    IF v_has_full_name AND v_has_is_blocked THEN
      EXECUTE v_sql USING NEW.id, v_name, false;
    ELSIF v_has_full_name AND NOT v_has_is_blocked THEN
      EXECUTE v_sql USING NEW.id, v_name;
    ELSIF NOT v_has_full_name AND v_has_is_blocked THEN
      EXECUTE v_sql USING NEW.id, false;
    ELSE
      EXECUTE v_sql USING NEW.id;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'handle_new_user: profile insert failed (auth user still created): SQLSTATE=% SQLERRM=%',
        SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user () IS
  'Naham: minimal profiles row on auth.users INSERT; dynamic columns; errors are WARNING only.';

-- ---------------------------------------------------------------------------
-- 3) Trigger (Supabase default name)
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user ();

-- ---------------------------------------------------------------------------
-- 4) PostgREST schema cache
-- ---------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
