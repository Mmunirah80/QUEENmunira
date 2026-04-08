import '../domain/entities/order_entity.dart';

/// Chef-side transitions on mapped [OrderStatus] (client reference only).
///
/// Server-side and Supabase datasource checks should use raw DB strings via
/// `OrderDbStatus.canChefAcceptDbStatus`, `canChefRejectDbStatus`, and `canChefAdvanceDbStatus`
/// in `order_db_status.dart`, because hydration can leave unknown values unmapped while the row is
/// still actionable.
///
/// Aligned conceptually with [public.is_valid_order_transition] (Supabase). Keep in sync with
/// `supabase_order_state_machine.sql` and patches (e.g. `supabase_orders_cancelled_by_system_v1.sql`).
abstract final class OrderCookTransition {
  OrderCookTransition._();

  static bool canChefAccept(OrderStatus current) => current == OrderStatus.pending;

  /// Decline / cancel from kitchen (maps to `cancelled_by_cook` in DB).
  static bool canChefReject(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
      case OrderStatus.accepted:
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return true;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return false;
    }
  }

  /// Advance pipeline: accepted → preparing → ready → completed.
  static bool isChefAdvance(OrderStatus from, OrderStatus to) {
    return switch ((from, to)) {
      (OrderStatus.accepted, OrderStatus.preparing) => true,
      (OrderStatus.preparing, OrderStatus.ready) => true,
      (OrderStatus.ready, OrderStatus.completed) => true,
      _ => false,
    };
  }
}
