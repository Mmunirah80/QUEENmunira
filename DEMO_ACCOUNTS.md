# NAHAM demo accounts

## Password

All users created by the SQL seeds use:

**``NahamDemo2026!**

---

## Run order (Supabase SQL Editor)

1. **`naham/tc/supabase_qa_diagnose.sql`** (optional — read-only checks)
2. **`naham/tc/supabase_chef_access_documents_v3.sql`**
3. **`naham/tc/supabase_chef_documents_two_types_migration_v1.sql`**
4. **`naham/tc/supabase_apply_chef_document_review.sql`**
5. **`naham/tc/supabase_orders_unified_cancel_v1.sql`** (optional — if you use `orders.cancel_reason`)
6. **`naham/tc/supabase_inspection_random_v2.sql`** (recommended before the demo-ready seed — adds inspection `outcome`, `chef_violations`, etc.)
7. **Seed (pick one):**
   - **Presentation demo (orders + chat + inspection + documents):**  
     **`naham/tc/supabase_demo_ready_v1.sql`**
   - **Older small 4-account seed:**  
     **`naham/tc/supabase_demo_clean_small_v1.sql`** (`cook_clean` / `cook_warning` — do not run both full seeds on the same DB without reset)
   - **Large matrix:**  
     **`naham/tc/supabase_demo_evaluation_seed_v1.sql`**

Stable UUID namespace in DB: `e0a00001-0000-4000-8de0-*`.

---

### Login shows “Database error querying schema”

PostgREST’s schema cache can lag after migrations or heavy SQL. Run in **SQL Editor**:

**`naham/tc/supabase_fix_auth_querying_schema_cache_v1.sql`**

(or paste: `NOTIFY pgrst, 'reload schema';`)

Then sign in again.

---

## Demo-ready presentation seed (`supabase_demo_ready_v1.sql`)

| Email | Role | Scenario | What to show in demo |
| --- | --- | --- | --- |
| [admin2@naham.com](mailto:admin2@naham.com) | Admin | Operations & compliance | **Inspections:** open **Inspections** / compliance views — see **Khalid — Inspection Demo** (`cook_inspection@naham.demo`) with **warning**, **3-day freeze**, completed call **`[demo-ready] inspection-khalid-hygiene`**, and **chef_violations** ledger row. **Documents:** open cook document review — **Layan — Documents Demo** has **ID approved** + **health/kitchen rejected** with visible rejection reason. |
| [cook_demo@naham.demo](mailto:cook_demo@naham.demo) | Cook | Orders + chat | **Orders:** **New** tab — pending salad order; **Active** — kabsa preparing; **Completed** — marqooq. **Chat:** thread with **customer_demo** — customer asks about kabsa, cook replies, realistic back-and-forth. **Menu:** three demo dishes. |
| [customer_demo@naham.demo](mailto:customer_demo@naham.demo) | Customer | Same pipeline | **Orders:** same three orders with **Matbakh Noura — Demo**. **Chat:** message cook; inbox shows the seeded thread. **Browse:** order from **cook_demo** kitchen. |
| [cook_inspection@naham.demo](mailto:cook_inspection@naham.demo) | Cook | Inspection / freeze | **Cook app:** frozen / warning state (banner if your UI reads `warning_count`, `freeze_until`). **Admin:** inspection history + violations for this kitchen name **Matbakh Khalid — Inspection**. |
| [cook_docs@naham.demo](mailto:cook_docs@naham.demo) | Cook | Document review | **Cook app → Documents:** **id_document** approved, **health_or_kitchen_document** **rejected** (blur / unreadable narrative). **Admin:** pending/approved/rejected queues show **Layan** clearly for live review storytelling. |

**Debug bypass (Flutter):** chef persona uses **`cook_demo@naham.demo`** and UUID **`c001`**; customer **`c003`**; admin **`a001`** — aligned with this seed.

### Flutter mock auth (no SQL required)

In **debug** builds, mock sign-in is **on** by default (`kBypassAuth` in `lib/core/debug/debug_auth_bypass.dart`). You open the app and use the **bug icon** (top-right) to switch Chef / Customer / Admin — no password.

- **Turn off mock** (real Supabase login): set `kBypassAuth` to `false` in that file, **or** run:  
  `flutter run --dart-define=NAHAM_MOCK_AUTH=false`  
- **Cook in-memory mock orders** (optional):  
  `flutter run --dart-define=COOK_MOCK_ORDERS=true` (debug only; uses fake order list for the cook).

---

## Legacy: small clean demo (`supabase_demo_clean_small_v1.sql`)

Uses **cook_clean@naham.demo** and **cook_warning@naham.demo** (not the demo-ready emails above). See that file’s header if you still use it.

---

## Full evaluation matrix (`supabase_demo_evaluation_seed_v1.sql`)

Many accounts. See the file header. Do not mix with `supabase_demo_ready_v1.sql` on the same DB without reset.

---

## Legacy QA emails (`supabase_qa_seed_cook_onboarding_matrix_v1.sql`)

Uses `@naham.qa.demo` addresses. Same password if inserted by that seed.
