import '../entities/chef_today_stats.dart';
import '../entities/order_entity.dart';

abstract class OrdersRepository {
  Future<List<OrderEntity>> getOrders({int? limit, int? offset});

  Future<List<OrderEntity>> getOrdersByStatus(
    OrderStatus status, {
    int? limit,
    int? offset,
  });

  Future<OrderEntity> getOrderById(String id);
  Future<void> acceptOrder(String id);
  Future<void> rejectOrder(String id, {String? reason});
  Future<void> updateOrderStatus(String id, OrderStatus status);

  Stream<List<OrderEntity>> watchOrders({List<OrderStatus>? statuses});

  Future<ChefTodayStats> getTodayStats();

  Future<List<OrderEntity>> getDelayedOrders(Duration threshold);

  /// For earnings screen: total earnings and last 7 days daily amounts from completed orders since [since].
  Future<({double totalEarnings, int totalCount, List<double> last7DaysEarnings})> getEarningsSummary(
    DateTime since, {
    int? completedOrdersLimit,
  });

  /// Customer places order. Returns new order id.
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
