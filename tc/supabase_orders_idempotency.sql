-- ============================================================
-- Orders idempotency support
-- ============================================================
-- Purpose:
-- - Prevent duplicate orders on client retries
-- - Keep one unique order per (customer_id, idempotency_key)
-- ============================================================

begin;

alter table public.orders
  add column if not exists idempotency_key uuid;

drop index if exists ux_orders_customer_chef_idempotency;

-- Unique per customer+request key. Partial index avoids legacy null rows.
create unique index if not exists ux_orders_customer_idempotency
  on public.orders (customer_id, idempotency_key)
  where idempotency_key is not null;

commit;

