-- ============================================================
-- NAHAM — Merge duplicate customer–chef conversations into one row per pair.
-- Run ONLY after backup on staging; review counts; then production.
--
-- Keeps the NEWEST conversation per (customer_id, chef_id), moves messages
-- from older rows into the keeper, deletes duplicate conversation rows.
-- ============================================================

BEGIN;

WITH ranked AS (
  SELECT
    id,
    customer_id,
    chef_id,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id, chef_id
      ORDER BY created_at DESC NULLS LAST, id
    ) AS rn
  FROM public.conversations
  WHERE
    type = 'customer-chef'
    AND chef_id IS NOT NULL
),
keepers AS (
  SELECT id AS keep_id, customer_id, chef_id
  FROM ranked
  WHERE rn = 1
),
to_drop AS (
  SELECT r.id AS drop_id, k.keep_id
  FROM ranked r
  INNER JOIN keepers k
    ON k.customer_id = r.customer_id
    AND k.chef_id = r.chef_id
  WHERE
    r.rn > 1
)
UPDATE public.messages m
SET conversation_id = d.keep_id
FROM to_drop d
WHERE m.conversation_id = d.drop_id;

WITH ranked AS (
  SELECT
    id,
    customer_id,
    chef_id,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id, chef_id
      ORDER BY created_at DESC NULLS LAST, id
    ) AS rn
  FROM public.conversations
  WHERE
    type = 'customer-chef'
    AND chef_id IS NOT NULL
)
DELETE FROM public.conversations c
WHERE c.id IN (
  SELECT id FROM ranked WHERE rn > 1
);

COMMIT;

-- After merge, apply unique index (see supabase_conversations_one_per_customer_chef.sql).
