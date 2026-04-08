import '../../orders/data/order_db_status.dart';

/// Buckets raw `orders.status` rows for the admin dashboard pipeline strip.
/// Unknown statuses fall through to **awaiting** (same as [adminOrderPipelineProvider]).
Map<String, int> adminOrderPipelineBucketsFromOrderRows(
  Iterable<Map<String, dynamic>> orders,
) {
  var awaiting = 0;
  var accepted = 0;
  var preparing = 0;
  var ready = 0;
  var completed = 0;
  var cancelled = 0;
  for (final r in orders) {
    final s = (r['status'] ?? '').toString();
    if (OrderDbStatus.pending.contains(s)) {
      awaiting++;
    } else if (s == 'accepted') {
      accepted++;
    } else if (OrderDbStatus.preparing.contains(s)) {
      preparing++;
    } else if (s == 'ready') {
      ready++;
    } else if (s == 'completed') {
      completed++;
    } else if (OrderDbStatus.cancelled.contains(s) || s == 'rejected') {
      cancelled++;
    } else {
      awaiting++;
    }
  }
  return {
    'awaiting': awaiting,
    'accepted': accepted,
    'preparing': preparing,
    'ready': ready,
    'completed': completed,
    'cancelled': cancelled,
  };
}
