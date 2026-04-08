import '../domain/entities/order_entity.dart';

/// Single source of truth for `orders.status` text in Postgres ↔ [OrderStatus].
abstract final class OrderDbStatus {
  OrderDbStatus._();

  /// Stored in `orders.cancel_reason` (Postgres). Never show raw values to customers.
  static const internalCookRejected = 'cook_rejected';
  static const internalSystemCancelledFrozen = 'system_cancelled_frozen';
  static const internalSystemCancelledBlocked = 'system_cancelled_blocked';

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
    'cancelled_by_system',
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
        return 'cancelled';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
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

  /// Chef Accept — only raw `orders.status` values that mean “waiting for cook”.
  /// Prefer this over [domainFromDb] so unknown strings cannot be mistaken for pending.
  static bool canChefAcceptDbStatus(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return false;
    return pending.contains(v);
  }

  /// Chef reject / decline — raw status before transition (not domain mapping).
  static bool canChefRejectDbStatus(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return false;
    if (pending.contains(v)) return true;
    if (v == 'accepted') return true;
    if (preparing.contains(v)) return true;
    if (v == 'ready') return true;
    return false;
  }

  /// Advance pipeline using **raw** DB status only (accepted → preparing → ready → completed).
  static bool canChefAdvanceDbStatus(String? raw, OrderStatus to) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return false;
    switch (to) {
      case OrderStatus.preparing:
        return v == 'accepted';
      case OrderStatus.ready:
        return preparing.contains(v);
      case OrderStatus.completed:
        return v == 'ready';
      case OrderStatus.pending:
      case OrderStatus.accepted:
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return false;
    }
  }

  static OrderStatus domainFromDb(String? v) {
    if (v == null || v.isEmpty) return OrderStatus.pending;
    if (pending.contains(v)) return OrderStatus.pending;
    if (v == 'accepted') return OrderStatus.accepted;
    if (v == 'rejected') return OrderStatus.rejected;
    if (preparing.contains(v)) return OrderStatus.preparing;
    if (v == 'ready') return OrderStatus.ready;
    if (v == 'completed') return OrderStatus.completed;
    if (v == 'cancelled') return OrderStatus.cancelled;
    if (cancelled.contains(v)) return OrderStatus.cancelled;
    return OrderStatus.pending;
  }

  /// Label for customer-facing UI (English). Only two cancellation messages are shown.
  /// Prefer [cancelReason] from `orders.cancel_reason` when present.
  /// When [rawDbStatus] is missing (e.g. legacy mocks), [orderStatusFallback] supplies text.
  static String customerFacingLabel(
    String? rawDbStatus, {
    String? cancelReason,
    bool detail = false,
    OrderStatus? orderStatusFallback,
  }) {
    final cr = (cancelReason ?? '').trim();
    if (cr == internalCookRejected) {
      return 'Rejected by cook';
    }
    if (cr == internalSystemCancelledFrozen || cr == internalSystemCancelledBlocked) {
      return 'Cancelled by system';
    }
    final r = (rawDbStatus ?? '').trim();
    if (r.isEmpty) {
      if (orderStatusFallback != null) {
        return _customerLabelFromDomain(orderStatusFallback, detail: detail);
      }
      return detail ? 'Waiting for acceptance' : 'Waiting';
    }
    if (r == 'paid_waiting_acceptance') return 'Paid · awaiting cook';
    if (pending.contains(r)) return detail ? 'Waiting for acceptance' : 'Waiting';
    if (r == 'accepted') return 'Accepted';
    if (r == 'rejected') return 'Rejected by cook';
    if (preparing.contains(r)) return 'Preparing';
    if (r == 'ready') return 'Ready';
    if (r == 'completed') return 'Completed';
    if (cancelled.contains(r)) {
      if (r == 'cancelled_by_cook' || r == 'rejected') {
        return 'Rejected by cook';
      }
      return 'Cancelled by system';
    }
    if (r.isNotEmpty && !recognizes(r)) {
      return detail ? 'Unknown status — contact support' : 'Unknown';
    }
    return 'Pending';
  }

  static String _customerLabelFromDomain(OrderStatus s, {bool detail = false}) {
    switch (s) {
      case OrderStatus.pending:
        return detail ? 'Waiting for acceptance' : 'Waiting';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.rejected:
        return 'Rejected by cook';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// One-line explanation when an order is no longer active (waiting screen / banners).
  static String customerCancellationSummary(
    String? rawDbStatus, {
    String? cancelReason,
    OrderStatus? orderStatusFallback,
  }) {
    final cr = (cancelReason ?? '').trim();
    if (cr == internalCookRejected) {
      return 'Rejected by cook';
    }
    if (cr == internalSystemCancelledFrozen || cr == internalSystemCancelledBlocked) {
      return 'Cancelled by system';
    }
    final r = (rawDbStatus ?? '').trim();
    if (r.isEmpty) {
      if (orderStatusFallback == OrderStatus.cancelled || orderStatusFallback == OrderStatus.rejected) {
        return 'Cancelled by system';
      }
      return 'Cancelled by system';
    }
    if (r == 'cancelled_by_cook' || r == 'rejected') {
      return 'Rejected by cook';
    }
    if (cancelled.contains(r)) return 'Cancelled by system';
    return 'Cancelled by system';
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
