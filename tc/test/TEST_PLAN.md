# NAHAM automated test plan

**Run tests with Flutter** (do not use `dart test` in this app): `flutter test` or `flutter test test/features/orders/...`.  
Adding the standalone `package:test` conflicts with the Flutter SDK’s pinned `flutter_test` / `test_api` versions.

This document maps product scenarios to **unit**, **widget**, **integration**, and **Supabase** tests.  
Implemented files live under `test/`; extend without renaming existing suites.

## Part 1 — Chef documents

| Scenario | Type | Notes |
|----------|------|--------|
| New chef uploads required docs → partial / waiting | Integration + DB | Drive registration + `chef_upsert_document`; assert `chef_profiles.access_level` via SQL or RPC. |
| Admin sees each `pending_review` row | Widget / Integration | `fetchPendingChefDocuments` list; assert one list tile per row id. |
| Approve one of two required → stays partial | Unit (server) | Prefer SQL test or RPC calling `recompute_chef_access_level` after `apply_chef_document_review`. |
| Approve both required → `full_access` | Unit (server) | Same as above with two approvals. |
| Reject one → partial; re-upload | Integration | Reject then `chef_upsert_document` → status `pending_review`. |
| Expired approved → notify; no auto “waiting” | Integration | Depends on `ChefExpiredDocumentsNotify` / notify job; assert `access_level` not flipped to blocked without review. |

**Unit tests added:** `test/features/cook/chef_documents_compliance_test.dart` (client-side gate only).

## Part 2 — Access / routing

| Scenario | Type | Notes |
|----------|------|--------|
| `partial_access` → only Chat + Profile | Widget / Integration | Pump `ChefShell` with `UserEntity` + `ChefDocModel` overrides; assert locked indices 0–3; tap snackbar path. |
| `full_access` → all tabs | Widget | Same with `isChefFullAccess`. |
| `blocked_access` → blocked screen | Integration | GoRouter redirect to `RouteNames.chefBlocked`. |

**Unit tests added:** `test/features/customer/customer_browse_storefront_gate_test.dart` (listing gate maps).  
**Future:** `test/routing/chef_shell_limited_tabs_test.dart` with `ProviderScope` overrides.

## Part 3 — Inspections

| Scenario | Type | Notes |
|----------|------|--------|
| Eligible = online, not vacation, in hours | Supabase | Assert `chef_inspection_eligibility_snapshot` JSON reasons in staging DB. |
| Random call succeeds / fails gracefully | Integration | Call `start_random_inspection_call` with controlled seed data; expect exception message when pool empty. |
| No duplicate open calls | Supabase | Two concurrent RPCs or unique index assertion. |
| Penalty ladder | Supabase | Repeated `finalize_inspection_outcome` with outcomes; assert `inspection_penalty_step` + freeze. |
| Frozen → no new orders | Integration | RLS + app: place order as customer when chef `freeze_until` active. |
| Blocked chef | Integration | Same as access blocked tests. |

**No automated file yet** — requires Supabase test project or `pgTAP` / SQL scripts in CI.

## Part 4 — Order cancellation

| Scenario | Type | Notes |
|----------|------|--------|
| Cook reject → “Rejected by cook” | Unit | `OrderDbStatus` + `cancel_reason` cook_rejected. |
| System frozen/blocked → “Cancelled by system” | Unit | internal reasons → labels. |
| No customer cancel | Integration / static | Grep / widget: no `cancelPendingOrderByCustomer`; payment rollback uses system reason. |

**Unit tests added:** `test/features/orders/order_db_status_cancellation_test.dart`.

## Part 5 — Admin chat monitor

| Scenario | Type | Notes |
|----------|------|--------|
| Normal mode: read + send | Widget | `AdminSupportConversationScreen(monitorOnly: false)` → finds `NahamChatInputBar`. |
| Monitor: read only | Widget | `monitorOnly: true` → `ChatMonitorBanner` present; **no** `NahamChatInputBar`. |
| Role labels | Unit | `resolveAdminMessageSenderRole` + label helpers. |

**Unit tests added:** `test/features/admin/admin_message_sender_role_test.dart`.  
**Widget tests to add:** `test/features/admin/admin_support_conversation_monitor_test.dart` (pump with fake `messagesStreamProvider`).

## Part 6 — Test pyramid

- **Unit:** domain mappers, compliance, role resolution, storefront gate (done / listed).
- **Widget:** `ChefShell`, `AdminSupportConversationScreen`, chat input visibility.
- **Integration:** `integration_test/` + real or Docker Supabase (add `integration_test` dev_dependency).
- **Backend:** SQL migrations applied to CI database; optional `supabase db test` or scripts.

## Manual / not fully automatable

- Agora / live inspection video.
- Push notifications for document expiry.
- Apple / Google payment flows.
- Exact RLS matrix across all roles (unless CI DB mirrors prod).

## Blockers

- No `integration_test` package in `pubspec.yaml` yet.
- No test Supabase project secrets in CI.
- `AdminSupportConversationScreen` uses live `Supabase.instance` in `_send` — widget tests need `ProviderScope` + overrides or refactor to inject client (optional).
