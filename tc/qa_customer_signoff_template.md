# Customer QA Sign-off Template

## Release Info
- Environment: `staging / production`
- Build: `app version + build number`
- Date:
- QA Owner:
- Engineering Owner:

## Pass/Fail Gates

| Gate | Status (Pass/Fail) | Evidence | Owner |
|---|---|---|---|
| Idempotency: double-tap creates one order/group |  |  |  |
| Idempotency: retry returns same order |  |  |  |
| App kill mid-order does not duplicate |  |  |  |
| Multi-order summary/track all works |  |  |  |
| Timeout writes `expired` terminal status |  |  |  |
| Cancel from pending writes `cancelled_by_customer` |  |  |  |
| Terminal transition blocked by DB |  |  |  |
| Stock restore runs once per order |  |  |  |
| Customer/Cook status sync realtime |  |  |  |
| Chat shows sending/failed/retry states |  |  |  |
| Chat retry succeeds after failure |  |  |  |
| Browse hides suspended/rejected cooks |  |  |  |
| Browse hides unapproved menu items |  |  |  |
| `transition_order_status` function exists |  |  |  |
| `trg_orders_state_machine` trigger exists |  |  |  |
| `get_customer_flow_alerts` function exists |  |  |  |
| Customer browse RLS policies present |  |  |  |
| Smoke test passed on Android release build |  |  |  |
| Weak-network checkout/chat stability passed |  |  |  |
| Crash-free session target met |  |  |  |

## Final Decision
- Verdict: `GO / NO-GO`
- Critical open items:
- Follow-up actions:

