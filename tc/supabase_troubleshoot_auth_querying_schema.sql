-- Run in Supabase Dashboard → SQL Editor when Auth returns:
-- {"code":"unexpected_failure","message":"Database error querying schema"}
-- (Flutter shows a longer hint; this is the same root cause.)
--
-- 0) Fast path — do this first (fixes most cases after migrations / seed runs).
NOTIFY pgrst, 'reload schema';
-- Hosted: Settings → API → Pause/Resume project or use Support if reload is not enough.
-- Local: `supabase stop` && `supabase start` or Docker restart for the API container.

-- 2) List public.profiles columns — any trigger inserting into profiles must only use these.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 3) Triggers on auth.users (new-user handlers often INSERT into public.profiles).
SELECT tgname, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'auth.users'::regclass
  AND NOT tgisinternal;

-- Full audit + safe handle_new_user replacement:
--   supabase_audit_auth_signin_failure_v1.sql
--   supabase_fix_auth_gotrue_500_profile_trigger_v1.sql (recommended: ALTER + function + trigger + NOTIFY)
--   supabase_fix_handle_new_user_safe_v1.sql (same function/trigger if ALTER already applied)
