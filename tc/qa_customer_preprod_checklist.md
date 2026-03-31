# Customer Pre-Prod Checklist

## A) Idempotency and order creation
- [ ] Double tap on `Place Order` creates exactly one order per cart group.
- [ ] Retry after network drop returns same `order_id` for same `idempotency_key`.
- [ ] App kill during placing order, reopen, retry: no duplicate order.
- [ ] Multi-order cart (2+ chefs) creates distinct orders with stable keys.
- [ ] Multi-order summary appears with all created order IDs.

## B) State machine and timeout
- [ ] Pending order auto-expiry transitions to `expired`.
- [ ] Customer cancel from pending transitions to `cancelled_by_customer`.
- [ ] Terminal statuses cannot transition to other statuses.
- [ ] `stock_restored` event is written once per canceled/expired pending order.
- [ ] No negative `remaining_quantity` under concurrent checkout.

## C) Customer/Cook synchronization
- [ ] Customer status and cook status match in realtime.
- [ ] Cancel/expire is visible on both customer and cook views.
- [ ] Multi-order tracking from customer shows all fresh orders.
- [ ] Cook accepts one order while another remains pending without cross-mix.

## D) Chat reliability
- [ ] Sending message shows optimistic `sending...` state.
- [ ] Failed send shows `failed - retry`.
- [ ] Retry successfully re-sends failed message and clears failed state.
- [ ] Chat list and conversation recovery works after reconnect.

## E) Admin moderation impact
- [ ] Suspended/rejected cook is hidden from customer browse.
- [ ] Rejected/unapproved menu item is hidden from customer browse.
- [ ] Same moderation behavior holds even if app filtering is bypassed (RLS check).

## F) Rollout gates
- [ ] `supabase_order_state_machine.sql` applied in staging.
- [ ] `supabase_customer_browse_rls_and_observability.sql` applied in staging.
- [ ] Smoke tests passed on Android production build.
- [ ] Crash-free checkout/chat journeys validated on weak network profile.

