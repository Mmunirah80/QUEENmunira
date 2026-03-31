-- Optional: scope cook–customer chat threads per order (multiple conversations per customer).
-- Run in Supabase SQL editor if you want separate chats per order.
-- Without this column, the app falls back to one conversation per customer pair.

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES public.orders (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_order_id
  ON public.conversations (order_id)
  WHERE order_id IS NOT NULL;

COMMENT ON COLUMN public.conversations.order_id IS
  'When set, messages belong to this order’s thread; NULL = legacy generic customer thread.';
