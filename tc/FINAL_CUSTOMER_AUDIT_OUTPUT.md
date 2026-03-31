# FINAL Customer Audit – Output

## 1. Complete list of files changed

| File | Changes |
|------|---------|
| `lib/features/auth/data/datasources/auth_supabase_datasource.dart` | Signup: robust flow (auto sign-in when no session), rate limit + already-registered handling, extra console prints; login: removed unnecessary cast |
| `lib/features/customer/screens/customer_main_navigation_screen.dart` | UI text: "Message chefs and support" → "Message cooks and support" |
| `lib/features/customer/screens/customer_order_details_screen.dart` | Comment: "chef info" → "cook info" |
| `lib/features/customer/screens/customer_payment_screen.dart` | In catch: added `print('Order insert error: $e');` for full error |
| `lib/features/customer/screens/customer_orders_screen.dart` | Status mapping: `_statusString(pending)` → `'pending'`, `_statusString(cancelled)` → `'cancelled'`; `_cancelledStatuses` extended with all cancelled variants so Active/Completed/Cancelled tabs match DB |
| `lib/features/customer/naham_customer_screens.dart` | Reels: added `print('[Reels] Like tap: ...')` on like tap |

**Already in place (no code change in this audit):**
- Order Details: timeline (5 steps), cancelled red banner with reason, "Waiting for cook...", pending countdown
- Orders: `customerId` + stream data prints, "Sign in to see your orders" when empty
- Payment: `customerId` prints at start, "Please sign in to place an order" snackbar, `Order insert error` in catch
- Chat: debug prints (customerID, conversations, length)
- Favorites: DishCard heart (isFavorite + onToggleFavorite from parent), Favorites screen from favorites table
- CustomerFirebaseDataSource: implemented with **Supabase** (no Firebase SDK) – no crash
- Waiting screen: title "Waiting for Cook", body "Waiting for cook to accept your order..."
- Reels: only like + cook name + caption (no comment/share icons)

---

## 2. Summary of what was fixed

### Auth signup (robust)
- **Prints:** `[Auth] signUp called: email=..., name=...`, `SignUp - user=..., session=...`, `No session after signUp; trying signInWithPassword`, `Auto sign-in succeeded`.
- **No session after signUp:** Tries `signInWithPassword` immediately; on success updates `profiles` (role, full_name, phone) and returns user; profile update failure is logged, not thrown.
- **Rate limit:** AuthException message checked for "rate limit" / "429" → friendly message.
- **Already registered:** Message checked for "already registered" / "email already registered" → "This email is already registered. Please sign in."
- **Profile update:** After signUp (with or without auto sign-in), profile update is in try/catch; non-fatal log only.

### UI / copy
- **Chef → Cook:** "Message chefs and support" → "Message cooks and support" (customer_main_navigation_screen). All other customer-facing strings already use "Cook" (Waiting for Cook, Chat with Cook, Cook Chats, etc.).
- **Comment:** Order details file comment "chef info" → "cook info".

### Orders
- **Status mapping:** `_statusString(OrderStatus.pending)` now returns `'pending'` (so Active tab shows pending orders). `_statusString(OrderStatus.cancelled)` returns `'cancelled'`.
- **Cancelled list:** `_cancelledStatuses` includes `'cancelled'`, `'cancelled_by_customer'`, `'cancelled_by_cook'`, `'cancelled_payment_failed'`, `'expired'` so all cancelled DB statuses appear in Cancelled tab.

### Payment
- **Full error in console:** In `_payNow` catch block, added `print('Order insert error: $e');` before existing Supabase error print.

### Reels
- **Debug on like:** `print('[Reels] Like tap: reelId=..., userId=..., isLiked=...');` when like is tapped.

### Lint
- **Auth:** Removed unnecessary `user as UserModel` cast in login (after null check, type is already promoted).

---

## 3. SQL you may need to run

No new SQL is required for this audit. Existing setup is assumed:

- **Profiles (for sign-up):** Trigger or RLS that creates a row in `profiles` on `auth.users` insert; and update allowed on `profiles` for the user’s own row (e.g. `role`, `full_name`, `phone`).
- **Test user:** If you use a fixed test user, ensure their profile exists and role is set, e.g.:
  ```sql
  UPDATE profiles
  SET role = 'customer', full_name = 'Naham Test'
  WHERE id = (SELECT id FROM auth.users WHERE email = 'nahamtest@gmail.com');
  ```
- **Orders:** Status values in DB: `pending`, `accepted`, `preparing`, `ready`, `completed`, `cancelled` (and any legacy: `cancelled_by_customer`, etc.).
- **Favorites:** Table `favorites` with `customer_id`, `item_id` (and optional `id`); RLS so customers can read/insert/delete their own rows.
- **Conversations / messages:** Tables `conversations` (e.g. `id`, `type`, `customer_id`, `chef_id`, `admin_id`, `created_at`) and `messages` (e.g. `conversation_id`, `sender_id`, `content`, `created_at` or `inserted_at`); RLS so customer can read/write their own data.

---

## 4. Remaining TODO items (for future milestones)

- **Cook side:** Arabic strings in cook screens (menu_screen, earnings_screen, bank_account_screen, chat_screen, profile_screen, settings_screen, etc.) – convert to English if app is English-only, or keep under l10n.
- **Auth repository:** `UnimplementedError('Reset password requires Supabase auth')` is only used when the remote datasource is *not* `AuthSupabaseDatasource`; with current Supabase auth it is never hit. Can be removed or clarified when cleaning auth abstraction.
- **Menu provider:** `UnimplementedError('Menu repository requires a logged-in chef')` is in cook/menu flow, not customer; leave for Cook milestone.
- **Orders Firebase datasource:** `UnimplementedError` in `orders_firebase_datasource.dart` is not used by customer (customer uses Supabase orders); leave for Orders/Cook if that path is ever used.
- **Print statements:** Many `print(...)` were added for debug. Consider replacing with `debugPrint` or a logger and stripping in release if desired.
- **Chat on Order Details:** "Chat with Cook" button currently shows "Chat coming soon" – when chat is wired to conversation by order, replace with real navigation.
- **Customer profile photo/addresses/notifications:** Implemented via `CustomerFirebaseDataSource` (Supabase under the hood). If any RLS or schema differs from expectations, add try/catch and user-friendly messages (partially already in place).

---

## 5. Verification summary

- **flutter analyze (customer + auth):** No **errors**; only info (e.g. avoid_print, prefer_const) and warnings (e.g. inference_failure_on_instance_creation). Safe to proceed.
- **Customer screens:** English-only in customer feature; "Cook" used in UI where relevant.
- **Buttons:** Pay Now, Like, Favorites heart, Cancel order, Chat with Cook (stub), etc. all have actions; no dead buttons in audited flows.
- **Loading / error / empty:** Orders, Chat, Favorites, Order Details, Payment, Reels use `.when(loading: ..., error: ..., data: ...)` or equivalent and show messages or retry where appropriate.
