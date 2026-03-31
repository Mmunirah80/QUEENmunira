-- ============================================================
-- Fix: duplicate conversations for same (customer_id, chef_id, customer-chef)
-- Your audit showed thread_count = 2 → customer getOrCreate may throw.
--
-- Run in Supabase → SQL Editor.
-- 1) Run SECTION A only first and read the rows.
-- 2) If both rows have order_id IS NULL (legacy one thread per pair), run SECTION B.
-- 3) If one row is per-order (order_id set), STOP — merge manually or adjust logic.
-- ============================================================

-- ----------------------------------------------------------------
-- SECTION A — PREVIEW (safe, read-only)
-- ----------------------------------------------------------------
SELECT c.id,
       c.customer_id,
       c.chef_id,
       c.type,
       c.order_id,
       c.created_at,
       (SELECT COUNT(*) FROM public.messages m WHERE m.conversation_id = c.id) AS message_count
FROM public.conversations c
WHERE c.type = 'customer-chef'
  AND c.customer_id = 'c6a03fc9-5d06-40d6-a037-9ca2174f962a'
  AND c.chef_id = 'a103a9b2-72ea-4d7d-9cbd-c47df4ab775b'
ORDER BY c.created_at NULLS LAST, c.id;

-- Optional: list ALL duplicate pairs (same as audit, with ids)
SELECT customer_id,
       chef_id,
       type,
       array_agg(id::text ORDER BY created_at NULLS LAST, id) AS conversation_ids,
       COUNT(*) AS thread_count
FROM public.conversations
WHERE type = 'customer-chef'
  AND order_id IS NULL
GROUP BY customer_id, chef_id, type
HAVING COUNT(*) > 1;

-- ----------------------------------------------------------------
-- SECTION B — MERGE (run only if preview shows 2 rows AND both order_id IS NULL)
-- Keeps oldest conversation (by created_at, then id); moves messages; deletes duplicate.
-- ----------------------------------------------------------------
BEGIN;

WITH ranked AS (
  SELECT id,
         customer_id,
         chef_id,
         ROW_NUMBER() OVER (
           PARTITION BY customer_id, chef_id
           ORDER BY created_at NULLS LAST, id
         ) AS rn
  FROM public.conversations
  WHERE type = 'customer-chef'
    AND order_id IS NULL
),
map AS (
  SELECT r1.id AS keep_id,
         r2.id AS drop_id
  FROM ranked r1
  JOIN ranked r2
    ON r1.customer_id = r2.customer_id
   AND r1.chef_id = r2.chef_id
   AND r1.rn = 1
   AND r2.rn > 1
)
UPDATE public.messages m
SET conversation_id = map.keep_id
FROM map
WHERE m.conversation_id = map.drop_id;

WITH ranked AS (
  SELECT id,
         customer_id,
         chef_id,
         ROW_NUMBER() OVER (
           PARTITION BY customer_id, chef_id
           ORDER BY created_at NULLS LAST, id
         ) AS rn
  FROM public.conversations
  WHERE type = 'customer-chef'
    AND order_id IS NULL
)
DELETE FROM public.conversations c
WHERE c.id IN (SELECT id FROM ranked WHERE rn > 1);

COMMIT;

-- ----------------------------------------------------------------
-- SECTION B2 — MERGE ONLY THIS PAIR (safer than B if you have many duplicates)
-- Uncomment and run instead of SECTION B if you want to fix only the two UUIDs above.
-- ----------------------------------------------------------------
/*
BEGIN;

WITH ranked AS (
  SELECT id,
         customer_id,
         chef_id,
         ROW_NUMBER() OVER (
           ORDER BY created_at NULLS LAST, id
         ) AS rn
  FROM public.conversations
  WHERE type = 'customer-chef'
    AND order_id IS NULL
    AND customer_id = 'c6a03fc9-5d06-40d6-a037-9ca2174f962a'
    AND chef_id = 'a103a9b2-72ea-4d7d-9cbd-c47df4ab775b'
),
map AS (
  SELECT r1.id AS keep_id,
         r2.id AS drop_id
  FROM ranked r1
  JOIN ranked r2 ON r1.rn = 1 AND r2.rn > 1
)
UPDATE public.messages m
SET conversation_id = map.keep_id
FROM map
WHERE m.conversation_id = map.drop_id;

WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (ORDER BY created_at NULLS LAST, id) AS rn
  FROM public.conversations
  WHERE type = 'customer-chef'
    AND order_id IS NULL
    AND customer_id = 'c6a03fc9-5d06-40d6-a037-9ca2174f962a'
    AND chef_id = 'a103a9b2-72ea-4d7d-9cbd-c47df4ab775b'
)
DELETE FROM public.conversations c
WHERE c.id IN (SELECT id FROM ranked WHERE rn > 1);

COMMIT;
*/

-- ----------------------------------------------------------------
-- SECTION C — OPTIONAL: stop duplicates from coming back (legacy threads only)
-- Run after B succeeds. Fails if duplicates still exist — fix those first.
-- ----------------------------------------------------------------
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_one_legacy_thread_per_pair
--   ON public.conversations (customer_id, chef_id)
--   WHERE type = 'customer-chef' AND order_id IS NULL;
