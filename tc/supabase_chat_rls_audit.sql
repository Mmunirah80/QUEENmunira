-- ============================================================
-- CHAT — automated check (run in Supabase → SQL Editor → Run)
-- Read the **Data** / **Results** tabs only. This file does NOT change data.
-- ============================================================

-- ----------------------------------------------------------------
-- 1) Do the tables exist?
-- ----------------------------------------------------------------
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('conversations', 'messages')
ORDER BY table_name;

-- ----------------------------------------------------------------
-- 2) Columns the Naham app expects (adjust if your names differ)
-- ----------------------------------------------------------------
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('conversations', 'messages')
ORDER BY table_name, ordinal_position;

-- ----------------------------------------------------------------
-- 3) Is RLS enabled? (relrowsecurity = true means RLS is ON)
-- ----------------------------------------------------------------
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN ('conversations', 'messages')
ORDER BY c.relname;

-- ----------------------------------------------------------------
-- 4) Every RLS policy on these tables (names + command + roles)
-- ----------------------------------------------------------------
SELECT schemaname,
       tablename,
       policyname,
       permissive,
       roles,
       cmd,
       qual::text AS using_expression,
       with_check::text AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('conversations', 'messages')
ORDER BY tablename, policyname;

-- ----------------------------------------------------------------
-- 5) Quick counts (sanity: zero rows = table missing or empty)
-- ----------------------------------------------------------------
SELECT 'conversations' AS tbl, COUNT(*)::bigint AS row_count FROM public.conversations
UNION ALL
SELECT 'messages', COUNT(*)::bigint FROM public.messages;

-- ----------------------------------------------------------------
-- 6) Duplicate customer–chef threads (breaks .maybeSingle() on customer)
--     Only meaningful if you have customer_id + chef_id on conversations.
-- ----------------------------------------------------------------
SELECT customer_id,
       chef_id,
       type,
       COUNT(*) AS thread_count
FROM public.conversations
WHERE type = 'customer-chef'
GROUP BY customer_id, chef_id, type
HAVING COUNT(*) > 1
ORDER BY thread_count DESC
LIMIT 50;
