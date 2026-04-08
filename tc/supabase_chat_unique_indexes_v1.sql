-- ============================================================
-- NAHAM — Chat: uniqueness for conversations (run after merge if duplicates exist)
-- ============================================================
-- 1) Optional: merge legacy duplicates (see supabase_chat_merge_duplicate_threads.sql
--    and supabase_conversations_one_per_customer_chef.sql).
-- 2) Then run the CREATE INDEX statements below in order.
--
-- Customer–chef: one row per (customer_id, chef_id) for type = customer-chef.
-- Customer–support: one row per customer for type = customer-support (chef_id IS NULL).

-- Customer–chef (partial unique; requires PostgreSQL)
CREATE UNIQUE INDEX IF NOT EXISTS conversations_customer_chef_unique
  ON public.conversations (customer_id, chef_id)
  WHERE type = 'customer-chef' AND chef_id IS NOT NULL;

-- One support inbox thread per customer (adjust WHERE if your schema stores support differently)
CREATE UNIQUE INDEX IF NOT EXISTS conversations_customer_support_unique
  ON public.conversations (customer_id)
  WHERE type = 'customer-support' AND chef_id IS NULL;

COMMENT ON INDEX conversations_customer_chef_unique IS
  'Prevents duplicate customer–chef threads; app retries on 23505 in getOrCreate.';
COMMENT ON INDEX conversations_customer_support_unique IS
  'Prevents duplicate customer-support threads; pair with getOrCreateCustomerSupportChat 23505 handling.';
