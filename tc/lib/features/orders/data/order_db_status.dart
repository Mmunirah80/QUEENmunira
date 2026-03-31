import '../domain/entities/order_entity.dart';

/// Single source of truth for `orders.status` text in Postgres ↔ [OrderStatus].
abstract final class OrderDbStatus {
  OrderDbStatus._();

  static const pending = {
    'pending',
    'paid_waiting_acceptance',
    'placed',
    'submitted',
    'awaiting_cook',
    'awaiting_acceptance',
    'new_order',
  };

  static const cancelled = {
    'cancelled',
    'cancelled_by_customer',
    'cancelled_by_cook',
    'cancelled_payment_failed',
    'expired',
  };

  static const preparing = {
    'preparing',
    'cooking',
    'in_progress',
    'in preparation',
  };

  /// DB strings to pass to `.inFilter('status', …)` for one domain tab.
  static List<String> filterValuesFor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return pending.toList();
      case OrderStatus.accepted:
        return const ['accepted'];
      case OrderStatus.rejected:
        return const ['rejected'];
      case OrderStatus.preparing:
        return preparing.toList();
      case OrderStatus.ready:
        return const ['ready'];
      case OrderStatus.completed:
        return const ['completed'];
      case OrderStatus.cancelled:
        return cancelled.toList();
    }
  }

  /// One DB value to write for a cook-driven [OrderStatus] change (not filters).
  static String mutationValueFor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.rejected:
        // DB state machine uses cancelled_by_cook for chef-side decline (not legacy "rejected").
        return 'cancelled_by_cook';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled_by_cook';
    }
  }

  /// True if this row counts as “still in the kitchen” for same-day ops metrics.
  static bool isInKitchenDbStatus(String? db) {
    if (db == null || db.isEmpty) return false;
    if (pending.contains(db)) return true;
    if (db == 'accepted') return true;
    if (preparing.contains(db)) return true;
    if (db == 'ready') return true;
    return false;
  }

  static bool isCompletedDbStatus(String? db) => db == 'completed';

  static bool isRejectedDbStatus(String? db) => db == 'rejected';

  static bool isCancelledDbStatus(String? db) =>
      db != null && cancelled.contains(db);

  static OrderStatus domainFromDb(String? v) {
    if (v == null || v.isEmpty) return OrderStatus.pending;
    if (pending.contains(v)) return OrderStatus.pending;
    if (v == 'accepted') return OrderStatus.accepted;
    if (v == 'rejected') return OrderStatus.rejected;
    if (preparing.contains(v)) return OrderStatus.preparing;
    if (v == 'ready') return OrderStatus.ready;
    if (v == 'completed') return OrderStatus.completed;
    if (cancelled.contains(v)) return OrderStatus.cancelled;
    return OrderStatus.pending;
  }

  static bool recognizes(String? v) {
    if (v == null || v.isEmpty) return true;
    if (pending.contains(v)) return true;
    if (v == 'accepted' || v == 'rejected' || v == 'ready' || v == 'completed') {
      return true;
    }
    if (preparing.contains(v)) return true;
    if (cancelled.contains(v)) return true;
    return false;
  }

  /// Non-terminal flows for SLA / delayed-order queries (excludes ready/completed/cancelled/rejected).
  static final List<String> delayedAttentionStatuses = <String>{
    ...pending,
    'accepted',
    ...preparing,
  }.toList();
}
