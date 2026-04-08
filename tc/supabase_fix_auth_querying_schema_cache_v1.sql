-- =============================================================================
-- Quick fix: "Database error querying schema" on login / Auth API
-- =============================================================================
-- PostgREST caches table columns. After migrations or manual DDL, the cache can
-- be stale and Auth/sign-in may fail until reloaded.
--
-- Run this in Supabase SQL Editor, then retry sign-in.
-- =============================================================================

NOTIFY pgrst, 'reload schema';

-- Optional: confirm profiles columns (any handle_new_user trigger must match).
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'profiles' ORDER BY ordinal_position;
