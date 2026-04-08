import '../../data/order_db_status.dart';
import '../../domain/entities/order_entity.dart';

/// Maps [OrderEntity] to the UI map shape used by order cards and order details.
/// When backend is connected, entities come from API; only this mapping may need tweaks.
class OrderUiMapper {
  OrderUiMapper._();

  /// First 8 characters of [id] for compact labels (e.g. `#a1b2c3d4`).
  /// Not globally unique; the full UUID from Supabase is the canonical order id.
  static String shortOrderId(String id) {
    final t = id.trim();
    if (t.isEmpty) return '—';
    if (t.length <= 8) return t;
    return t.substring(0, 8);
  }

  static String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  static String _formatTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  static String itemsString(OrderEntity order) {
    return order.items
        .map((i) => '${i.quantity}x ${i.dishName}')
        .join(', ');
  }

  /// For New (pending) tab cards.
  static Map<String, dynamic> toNewOrderMap(OrderEntity order) {
    return {
      'id': order.id,
      'customer': order.customerName,
      'items': itemsString(order),
      'earnings': order.totalAmount,
      'prepTime': '—',
      'placed': _timeAgo(order.createdAt),
      'note': order.notes ?? '',
    };
  }

  /// For Active tab cards.
  static Map<String, dynamic> toActiveOrderMap(OrderEntity order) {
    final status = order.status == OrderStatus.preparing ? 'Almost Ready' : 'Cooking';
    final est = order.createdAt.add(const Duration(minutes: 45));
    return {
      'id': order.id,
      'customer': order.customerName,
      'items': itemsString(order),
      'amount': order.totalAmount,
      'status': status,
      'readyIn': '—',
      'estTime': _formatTime(est),
    };
  }

  /// For Completed tab cards.
  static Map<String, dynamic> toCompletedOrderMap(OrderEntity order) {
    return {
      'id': order.id,
      'customer': order.customerName,
      'items': itemsString(order),
      'amount': order.totalAmount,
      'completedAt': _formatTime(order.createdAt),
    };
  }

  /// For Cancelled tab cards.
  static Map<String, dynamic> toCancelledOrderMap(OrderEntity order) {
    return {
      'id': order.id,
      'customer': order.customerName,
      'items': itemsString(order),
      'amount': order.totalAmount,
      'status': OrderDbStatus.customerFacingLabel(
        order.dbStatus,
        cancelReason: order.cancelReason,
        orderStatusFallback: order.status,
      ),
    };
  }

  /// Full map for order details screen (new type).
  static Map<String, dynamic> toDetailsMapNew(OrderEntity order) {
    return {
      ...toNewOrderMap(order),
      'earnings': order.totalAmount,
    };
  }

  /// Full map for order details screen (active type).
  static Map<String, dynamic> toDetailsMapActive(OrderEntity order) {
    final m = toActiveOrderMap(order);
    return {
      ...m,
      'readyIn': m['readyIn'] as String,
      'estTime': m['estTime'] as String,
    };
  }

  /// Full map for order details screen (completed type).
  static Map<String, dynamic> toDetailsMapCompleted(OrderEntity order) {
    return toCompletedOrderMap(order);
  }

  /// Full map for order details screen (cancelled type).
  static Map<String, dynamic> toDetailsMapCancelled(OrderEntity order) {
    return toCancelledOrderMap(order);
  }
}
