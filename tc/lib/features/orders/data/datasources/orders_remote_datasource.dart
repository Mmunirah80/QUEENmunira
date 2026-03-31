import '../../domain/entities/chef_today_stats.dart';
import '../../domain/entities/order_entity.dart';
import '../models/order_model.dart';

abstract class OrdersRemoteDataSource {
  /// [limit] defaults to 150; capped at 500. [offset] defaults to 0 (pagination).
  Future<List<OrderModel>> getOrders({int? limit, int? offset});

  Future<List<OrderModel>> getOrdersByStatus(
    OrderStatus status, {
    int? limit,
    int? offset,
  });

  Future<OrderModel> getOrderById(String id);
  Future<void> acceptOrder(String id);
  Future<void> rejectOrder(String id, {String? reason});
  Future<void> updateOrderStatus(String id, OrderStatus status);

  /// Real-time stream. [statuses] null = all; otherwise filter by status in list.
  Stream<List<OrderModel>> watchOrders({List<OrderStatus>? statuses});

  Future<ChefTodayStats> getTodayStats();

  Future<List<OrderModel>> getDelayedOrders(Duration threshold);

  /// [limit] defaults to 500; capped at 1000.
  Future<List<OrderModel>> getCompletedOrdersSince(
    DateTime since, {
    int? limit,
  });

  /// Create order (customer places order). Returns new order id.
  /// [idempotencyKey] enables safe retries (same key ⇒ same order id when supported by backend).
  Future<String> createOrder({
    required String customerId,
    required String customerName,
    required String chefId,
    required String chefName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? deliveryAddress,
    String? notes,
    String? idempotencyKey,
  });
}
