# Presentation demo seed — Naham (Flutter + Supabase)

This document accompanies **`supabase_presentation_demo_seed.sql`**. It describes the seeding plan, which files matter, how to back up safely, what to verify after running the script, and Flutter notes.

---

## 1. Seeding plan (what the script builds)

| Actor | Email | Role in story |
|--------|--------|----------------|
| Admin | `naham@naham.com` | Existing admin; script sets `profiles.role = 'admin'`. |
| Sarah | `chef.sarah@naham.present` | Established chef: high `rating_avg` / `total_orders`, menu, old completed orders, reel + likes, inspection “pass”. |
| Marcus | `chef.marcus@naham.present` | Second active kitchen: orders, chat with Alex, pending inspection row. |
| James | `chef.james@naham.present` | New chef: recent `initial_approval_at`, small menu, pending order from Sam. |
| Alex (pending app) | `chef.pending@naham.present` | Pending approval: `approval_status = 'pending'`, documents pending, sample menu in moderation. |
| Jordan | `chef.frozen@naham.present` | Suspended / frozen: `suspended = true`, `freeze_*` / `warning_count` populated where columns exist. |
| Elena | `customer.elena@naham.present` | Long history: multiple addresses, completed + cancelled orders, chat with Sarah, support thread with admin. |
| Alex | `customer.alex@naham.present` | Multi-chef: active orders (accepted + preparing) across Sarah and Marcus, reel like, chat with Marcus. |
| Sam | `customer.sam@naham.present` | New: recent `pending` order with James. |
| Riley | `customer.riley@naham.present` | Favorites on Sarah + Marcus dishes (engagement). **Cart is not stored in DB** — add items in the app after login. |
| Maya | `customer.maya@naham.present` | Light activity: one completed order, reel like. |

**Tagging for cleanup:** `orders.notes`, `notifications.title`, and `inspection_calls.channel_name` use the prefix **`[naham-present]`** so deletes stay scoped. Rows tied to the listed `@naham.present` Auth users are removed in FK-safe order (messages → conversations → reel data → order graph → notifications → inspection → favorites, addresses, documents, menu, `chef_profiles`).

**Order statuses** use values compatible with `OrderDbStatus` and `supabase_order_state_machine.sql` (e.g. `pending`, `accepted`, `preparing`, `completed`, `cancelled_by_customer`).

**Reviews:** There is no separate reviews table in this project path; chef quality is reflected via **`chef_profiles.rating_avg`** and **`total_orders`** when those columns exist.

**English-only:** All seeded user-visible strings (names, bios, dishes, messages, notifications) are in English.

---

## 2. Files involved

| File | Purpose |
|------|---------|
| `naham/tc/supabase_presentation_demo_seed.sql` | **Single script:** optional column guards, DELETE block, full INSERT seed (~30 menus, 24 orders, 55 order lines, 8 chats, 55 msgs, 9 reels, 28 likes). |
| `naham/tc/supabase_order_state_machine.sql` | Reference for allowed `orders.status` values and triggers. |
| `naham/tc/lib/features/orders/data/order_db_status.dart` | App mapping for DB status ↔ UI; keep seeded statuses within recognized sets. |
| `naham/tc/lib/core/constants/demo_location.dart` | Default customer pickup (Riyadh); aligns with seeded `kitchen_latitude` / `kitchen_longitude` / city text. |

No Flutter code change is **required** for the seed to run; see section 4.

---

## 3. Backup / export before running

Do at least one of the following (production or shared projects):

1. **Supabase Dashboard → Database → Backups** (PITR / scheduled backup), or  
2. **`pg_dump`** of the project, or  
3. **Table Editor** CSV export for critical tables (`orders`, `order_items`, `profiles`, `chef_profiles`, …).

The script **does not delete** arbitrary legacy demo rows (e.g. old UUIDs from other mock SQL files). It removes:

- Presentation-tagged rows (`[naham-present%`), and  
- Data for the fixed `@naham.present` Auth user IDs.

To **fully** replace unrelated old demo data, extend the DELETE section or run a one-off purge for those UUIDs after backup.

---

## 4. Prerequisites (must exist before seed)

1. **Auth users** created in Supabase Authentication (email confirmed as your project allows):

   - `naham@naham.com`  
   - Chefs: `chef.sarah@naham.present`, `chef.marcus@naham.present`, `chef.james@naham.present`, `chef.pending@naham.present`, `chef.frozen@naham.present`  
   - Customers: `customer.elena@naham.present`, `customer.alex@naham.present`, `customer.sam@naham.present`, `customer.riley@naham.present`, `customer.maya@naham.present`

2. **`public.profiles`** rows for those users (typically created by your signup trigger). The script **UPDATE**s names, phones, cities, and roles for demo users.

3. Run the SQL in the **SQL Editor** as a role that bypasses RLS (e.g. **postgres** / **service role**), same as other migration scripts in `naham/tc/`.

---

## 5. Flutter-side notes

- **Cart:** Stored in app memory / local state, not in Postgres. For a “cart” slide, log in as **Riley** and add dishes manually; favorites are already seeded.  
- **Demo location:** `demo_location.dart` uses Riyadh coordinates so “nearby” chefs behave predictably; seeded kitchens are in Riyadh.  
- **No hardcoded `@naham.present` emails** were required in Dart for this seed; login uses whatever auth flow you already use.

If you later centralize demo emails in Dart constants, point them at the table above.

---

## 6. Post-run verification checklist

**Auth & profiles**

- [ ] Log in as `naham@naham.com` — admin screens load; support conversation shows admin reply.  
- [ ] Each `@naham.present` user logs in; **English** names and roles look correct.

**Chef**

- [ ] Sarah: menu, reel, likes count, high order/rating stats, completed history.  
- [ ] Marcus: second kitchen, chat with Alex, inspection row if table exists.  
- [ ] James: small menu, `pending` order visible to cook flow.  
- [ ] Pending chef: approval queue / pending documents in admin.  
- [ ] Frozen chef: hidden or blocked as your UI implements `suspended` / freeze fields.

**Customer**

- [ ] Elena: multiple addresses, completed + cancelled orders, customer–chef + support threads.  
- [ ] Alex: orders in **accepted** and **preparing** with different chefs.  
- [ ] Sam: new user story + `pending` order.  
- [ ] Riley: favorites present; cart demo done manually in app.  
- [ ] Maya: light history + reel engagement.

**Orders**

- [ ] Order list tabs (pending / active / completed / cancelled) show sensible rows.  
- [ ] Status strings match `order_db_status.dart` (no “unknown status” everywhere).

**Data integrity**

- [ ] No FK errors when opening order detail, chat, or chef profile.  
- [ ] Re-run script idempotently: second run completes without duplicate key errors (relies on `ON CONFLICT` where used and DELETE cleanup).

---

## 7. Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `Admin not found` | Auth user `naham@naham.com` missing. |
| `Create these Auth users first: …` | One or more `@naham.present` users not in `auth.users`. |
| FK violation on insert | Schema drift (column renames); compare `INSERT` lists with live `information_schema.columns`. |
| RLS blocks in app | Expected for anon key; SQL Editor should use service role. App uses user JWT. |
| Duplicate chef_documents | Unique constraint on `(chef_id, document_type)` — delete block should clear first; add `ON CONFLICT` if your DB differs. |

---

*Last aligned with `supabase_presentation_demo_seed.sql` and `OrderDbStatus` (2026).*
