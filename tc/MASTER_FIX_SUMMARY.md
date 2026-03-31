# NAHAM Customer Screens – Master Fix Summary

## 1. Summary of changes

### Language (Arabic → English)
- **naham_customer_screens.dart**: All Arabic strings replaced with English:
  - Kitchen demo data: cuisine (إيطالي → Italian, عربي → Arabic, etc.), time (دقيقة → min), badges (الأكثر طلباً → Most ordered, جديد → New).
  - Promo card: عرض اليوم → Today's offer, خصم 20% → 20% off, على أول طلب لك → On your first order.
  - Dish card CTA: أضف للسلة + → Add to cart +.
  - Orders: طلباتي → My Orders, نشطة/السجل → Active/History, empty states and Retry button.
  - Order status labels: قيد الانتظار → Pending, مقبول → Accepted, etc.
  - Order items join: Arabic comma (،) → comma (,); chef fallback طاهي → Chef.
  - Chat: المحادثات → Conversations, مع الطهاة/الدعم → With chefs/Support, empty states, لا رسائل → No messages, اكتب رسالة → Type a message.
  - Web: header, tagline, search hint, اختر موقعك → Choose your location, stats (مطعم منزلي → Home kitchens, متوسط التوصيل → Avg. delivery, متوسط التقييم → Avg. rating).
- **customer_chat_firebase_datasource.dart**: دعم نهم → Naham Support.

### Profile & auth bypass
- Profile screen already shows test customer when `authStateProvider` is null (`displayUser = user ?? _testCustomerEntity` with name "Test Customer").
- Edit Profile: uses `ref.read(customerIdProvider)` for Supabase `updateCustomerProfile` and photo upload when auth is bypassed.
- Favorites, Addresses, Notifications: all use `customerIdProvider` (test customer ID when auth is null).

### Addresses
- Replaced `uid != null` with `uid.isNotEmpty` for set-default and delete actions.
- `_openAddressForm` now takes `required String uid` and checks `uid.isEmpty`; removed RTL `Directionality` from the add/edit address bottom sheet.

### Payment
- **customer_payment_screen.dart**: Fallback customer name when user is null changed from `'Customer'` to `'Test Customer'`.

### Already in place (unchanged)
- **customer_main_navigation_screen.dart**: Chat tab shows "Chat – Coming Soon" placeholder.
- **customer_orders_screen.dart**: 3 tabs (Active, Completed, Cancelled), `customerOrdersStreamProvider`, empty states, English.
- **customer_order_details_screen.dart**: Order info, items, chef, "Chat with Chef" (toast "Chat coming soon").
- **customer_payment_screen.dart**: Creates orders in Supabase, 10% commission, clears cart, navigates to Waiting screen.
- **customer_waiting_for_chef_screen.dart**: 5‑min timer, realtime status, cancel, navigate on accept/expire.
- **customer_cart_screen.dart**: Checkout → Payment, English.
- Reels tab: "Reels - Coming Soon" placeholder in `naham_customer_screens.dart` (NahamCustomerReelsScreen).

---

## 2. SQL to run in Supabase (if needed)

Use **only** the parts that match your current schema. Do **not** recreate existing tables.

### If `order_items` does not exist
```sql
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
```

### If `reels` does not exist (for future Reels milestone)
```sql
CREATE TABLE IF NOT EXISTS reels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chef_id UUID REFERENCES profiles(id),
  video_url TEXT,
  thumbnail_url TEXT,
  caption TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### If `reel_likes` does not exist
```sql
CREATE TABLE IF NOT EXISTS reel_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reel_id UUID NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(reel_id, customer_id)
);
CREATE INDEX IF NOT EXISTS idx_reel_likes_reel_id ON reel_likes(reel_id);
CREATE INDEX IF NOT EXISTS idx_reel_likes_customer_id ON reel_likes(customer_id);
```

### Optional: `addresses.phone`
If your `addresses` table does not have a `phone` column and you want it in the UI:
```sql
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS phone TEXT;
```

### RLS (if you use Row Level Security)
Example for customers seeing only their own orders (adjust for your `auth.uid()` vs `customer_id`):
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Customers can view own orders" ON orders FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Customers can insert own orders" ON orders FOR INSERT WITH CHECK (auth.uid() = customer_id);
```

Full reference: `supabase_customer_migrations.sql` in the project root.

---

## 3. Still TODO for future milestones

- **Stripe / real payments**: Payment screen currently creates the order directly; integrate Stripe (or other gateway) when going live.
- **Chat with chefs**: Implement real conversations (Supabase `conversations` / `messages` or existing Firebase path); currently "Chat – Coming Soon" toast and placeholder.
- **Reels**: Implement reels content and likes using `reels` and `reel_likes` tables; currently "Reels – Coming Soon" placeholder.
- **Auth**: Remove test customer bypass and wire Profile/orders/favorites/addresses/notifications to real `auth.uid()`.
- **Order flow**: Chef app acceptance/rejection, status updates, and any push notifications for order status changes.
