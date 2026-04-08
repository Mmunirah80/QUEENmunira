import '../../domain/entities/chef_today_stats.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/orders_repository.dart';
import '../datasources/orders_firebase_datasource.dart';
import '../datasources/orders_remote_datasource.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl({
    OrdersRemoteDataSource? remoteDataSource,
    String? chefId,
    String? customerId,
  }) : remoteDataSource = remoteDataSource ??
            OrdersSupabaseDataSource(chefId: chefId, customerId: customerId);

  final OrdersRemoteDataSource remoteDataSource;

  @override
  Future<List<OrderEntity>> getOrders({int? limit, int? offset}) {
    return remoteDataSource.getOrders(limit: limit, offset: offset);
  }

  @override
  Future<List<OrderEntity>> getOrdersByStatus(
    OrderStatus status, {
    int? limit,
    int? offset,
  }) {
    return remoteDataSource.getOrdersByStatus(
      status,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<OrderEntity> getOrderById(String id) {
    return remoteDataSource.getOrderById(id);
  }

  @override
  Future<void> acceptOrder(String id) {
    return remoteDataSource.acceptOrder(id);
  }

  @override
  Future<void> rejectOrder(String id, {String? reason}) {
    return remoteDataSource.rejectOrder(id, reason: reason);
  }

  @override
  Future<void> updateOrderStatus(String id, OrderStatus status) {
    return remoteDataSource.updateOrderStatus(id, status);
  }

  @override
  Stream<List<OrderEntity>> watchOrders({List<OrderStatus>? statuses}) {
    return remoteDataSource.watchOrders(statuses: statuses);
  }

  @override
  Future<ChefTodayStats> getTodayStats() {
    return remoteDataSource.getTodayStats();
  }

  @override
  Future<List<OrderEntity>> getDelayedOrders(Duration threshold) {
    return remoteDataSource.getDelayedOrders(threshold);
  }

  @override
  Future<({double totalEarnings, int totalCount, List<double> last7DaysEarnings})>
      getEarningsSummary(
    DateTime since, {
    int? completedOrdersLimit,
  }) async {
    final orders = await remoteDataSource.getCompletedOrdersSince(
      since,
      limit: completedOrdersLimit,
    );
    final totalEarnings = orders.fold<double>(0, (s, o) => s + o.totalAmount);
    final now = DateTime.now();
    final last7 = List<double>.filled(7, 0);
    for (final o in orders) {
      final created = o.createdAt;
      final daysAgo = now.difference(created).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        last7[6 - daysAgo] += o.totalAmount;
      }
    }
    return (
      totalEarnings: totalEarnings,
      totalCount: orders.length,
      last7DaysEarnings: last7,
    );
  }

  @override
  Future<String> createOrder({
    required String customerId,
    required String customerName,
    required String chefId,
    required String chefName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double commissionAmount = 0,
    String? deliveryAddress,
    String? notes,
    String? idempotencyKey,
  }) {
    return remoteDataSource.createOrder(
      customerId: customerId,
      customerName: customerName,
      chefId: chefId,
      chefName: chefName,
      items: items,
      totalAmount: totalAmount,
      commissionAmount: commissionAmount,
      deliveryAddress: deliveryAddress,
      notes: notes,
      idempotencyKey: idempotencyKey,
    );
  }
}
