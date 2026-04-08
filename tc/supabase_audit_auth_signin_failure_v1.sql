-- =============================================================================
-- NAHAM — Audit: Auth sign-in / "Database error querying schema"
-- =============================================================================
-- Run in Supabase SQL Editor (project owner). Read-only except optional NOTIFY.
--
-- Flutter proved failure inside signInWithPassword (GoTrue 500). Common causes:
--   1) PostgREST schema cache stale → NOTIFY below (hosted: may still need API restart).
--   2) Trigger on auth.users (INSERT or UPDATE) runs broken PL/pgSQL (wrong columns).
--   3) Rare: auth schema / extension issues → see Postgres Logs in Dashboard.
-- =============================================================================

-- 0) Optional fast path (safe to run)
-- NOTIFY pgrst, 'reload schema';

-- 1) public.profiles columns — compare with your handle_new_user INSERT list.
SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 2) All NON-INTERNAL triggers on auth.users (names + full definitions)
SELECT
  t.tgname AS trigger_name,
  CASE t.tgenabled
    WHEN 'O' THEN 'origin'
    WHEN 'D' THEN 'disabled'
    WHEN 'R' THEN 'replica'
    WHEN 'A' THEN 'always'
    ELSE t.tgenabled::text
  END AS enabled,
  pg_get_triggerdef(t.oid, true) AS trigger_definition
FROM pg_trigger t
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal
ORDER BY t.tgname;

-- 3) Full source of every function used by those triggers
SELECT
  t.tgname AS trigger_name,
  p.proname AS function_name,
  n.nspname AS function_schema,
  pg_get_functiondef(p.oid) AS function_body
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal
ORDER BY t.tgname;

-- 4) public functions whose source mentions profiles + email (stale handle_new_user)
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_functiondef(p.oid) AS function_body
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%profiles%'
  AND pg_get_functiondef(p.oid) ILIKE '%email%'
ORDER BY p.proname;

-- 5) public functions mentioning raw_user_meta_data (typical signup triggers)
SELECT
  p.proname AS function_name,
  pg_get_functiondef(p.oid) AS function_body
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%raw_user_meta_data%'
ORDER BY p.proname;

-- 6) Triggers on public.profiles that run on INSERT (can break first profile row)
SELECT
  t.tgname,
  pg_get_triggerdef(t.oid, true) AS definition
FROM pg_trigger t
WHERE t.tgrelid = 'public.profiles'::regclass
  AND NOT t.tgisinternal
ORDER BY t.tgname;
