/// Chef must accept within this window after [orders.created_at] (matches Supabase
/// [expire_stale_pending_orders] and customer waiting UI).
const Duration kChefAcceptanceTimeout = Duration(minutes: 5);

/// UTC deadline for a pending order to be accepted.
DateTime pendingAcceptanceDeadlineUtc(DateTime orderCreatedAtUtc) {
  return orderCreatedAtUtc.toUtc().add(kChefAcceptanceTimeout);
}

/// Seconds until [pendingAcceptanceDeadlineUtc], or 0 if past.
int remainingAcceptanceSeconds(DateTime orderCreatedAtUtc, DateTime nowUtc) {
  final end = pendingAcceptanceDeadlineUtc(orderCreatedAtUtc);
  final s = end.difference(nowUtc.toUtc()).inSeconds;
  return s < 0 ? 0 : s;
}

bool isPastAcceptanceDeadline(DateTime orderCreatedAtUtc, DateTime nowUtc) {
  return remainingAcceptanceSeconds(orderCreatedAtUtc, nowUtc) <= 0;
}
