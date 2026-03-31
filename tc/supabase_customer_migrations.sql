-- ============================================================
-- NAHAM Customer – Optional SQL to run in Supabase if tables/columns are missing
-- Run only the parts you need. Existing tables are NOT recreated.
-- ============================================================

-- 1) ORDER_ITEMS – Required for Payment → Create Order flow.
--    If your order_items table has different column names, adjust the app to match.
--    dish_name is optional but recommended for display without joining menu_items.
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  dish_id UUID NOT NULL,
  dish_name TEXT,
  quantity INT NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- 2) ORDERS – Ensure status can hold these values (if you use an enum, extend it):
--    paid_waiting_acceptance, accepted, preparing, ready, completed,
--    cancelled_by_customer, cancelled_by_cook, cancelled_payment_failed, expired, rejected
-- If orders.status is TEXT, no change needed. If it's an enum, add the above values.

-- 3) REELS – Only if you don't have this table yet (for future Reels milestone).
--    dish_id has no FK here so this block runs even before menu_items exists.
--    Run supabase_reels_system.sql afterward for FK + RLS + storage.
CREATE TABLE IF NOT EXISTS reels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chef_id UUID REFERENCES profiles(id),
  video_url TEXT,
  thumbnail_url TEXT,
  caption TEXT,
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  dish_id UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4) REEL_LIKES – Only if you don't have this table yet.
CREATE TABLE IF NOT EXISTS reel_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reel_id UUID NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(reel_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_reel_likes_reel_id ON reel_likes(reel_id);
CREATE INDEX IF NOT EXISTS idx_reel_likes_customer_id ON reel_likes(customer_id);

-- 5) CONVERSATIONS – For Chat (Milestone 6). Run if table doesn't exist.
--    App expects: id, customer_id, chef_id (nullable), type ('customer-chef' | 'customer-support'),
--    last_message, last_message_at, created_at, updated_at.
--    Optional: other_participant_name (for display without joining profiles).
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  chef_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('customer-chef', 'customer-support')),
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_conversations_customer_id ON conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_conversations_type ON conversations(type);

-- 6) MESSAGES – For Chat. App expects: id, conversation_id, sender_id, content, created_at.
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);

-- 7) ADDRESSES – If your table is missing optional phone column (app uses it in UI):
-- ALTER TABLE addresses ADD COLUMN IF NOT EXISTS phone TEXT;

-- 8) RLS – Enable if you use Row Level Security. Example for orders (customer sees own orders):
-- ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Customers can view own orders" ON orders FOR SELECT USING (auth.uid() = customer_id);
-- CREATE POLICY "Customers can insert own orders" ON orders FOR INSERT WITH CHECK (auth.uid() = customer_id);
-- (Adjust for your auth.uid() vs customer_id usage.)
