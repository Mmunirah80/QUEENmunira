# Customer Go-Live 48h Runbook

## T-48h
- Verify SQL migrations are applied:
  - `supabase_order_state_machine.sql`
  - `supabase_customer_browse_rls_and_observability.sql`
- Run DB verification queries and store screenshots/results.
- Freeze schema changes except hotfixes.

## T-24h
- Execute `qa_customer_preprod_checklist.md` end-to-end on staging.
- Fill `qa_customer_signoff_template.md`.
- Fix any failing gates and rerun failed scenarios.

## T-12h
- Build Android release candidate.
- Run smoke tests:
  - customer login/signup
  - place single order
  - place multi-order
  - cancel/expire flow
  - chat send + retry
- Confirm no crash in checkout/chat critical paths.

## T-4h
- Re-run DB function/policy existence checks.
- Validate alerts output from `get_customer_flow_alerts(15)`.
- Confirm monitoring/dashboard visibility for stale pending orders.

## T-0 (Launch)
- Release app build.
- Monitor first 60 minutes:
  - order creation success rate
  - duplicate order rate
  - chat failure/retry counts
  - stale pending count
- Prepare rollback owner and communication channel.

## Rollback Triggers
- Duplicate order spike above threshold.
- Invalid status transition errors above threshold.
- Chat send failure sustained above threshold.
- Checkout crash loop in production.

