import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/local_calendar_day_utc_bounds.dart';
import '../../domain/entities/chef_today_stats.dart';
import '../../domain/entities/order_entity.dart';
import '../models/order_model.dart';
import 'orders_remote_datasource.dart';

/// Mock data for orders. When backend is ready, use [OrdersRemoteDataSource]
/// (API implementation) in [OrdersRepositoryImpl] and remove or keep this for tests.
class OrdersMockDataSource implements OrdersRemoteDataSource {
  final List<OrderModel> _orders = [];

  OrdersMockDataSource() {
    _initializeMockData();
  }

  void _initializeMockData() {
    // New (pending) orders
    _orders.addAll([
      OrderModel(
        id: '#2053',
        customerName: 'Sara Ahmed',
        customerImageUrl: null,
        items: [
          const OrderItemModel(id: 'i1', dishName: 'Jareesh', quantity: 2, price: 22.0),
          const OrderItemModel(id: 'i2', dishName: 'Margog', quantity: 1, price: 21.0),
        ],
        totalAmount: 65.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        deliveryAddress: 'Riyadh, Al Olaya',
        notes: 'Less spicy please',
      ),
      OrderModel(
        id: '#2052',
        customerName: 'Omar Hassan',
        customerImageUrl: null,
        items: [
          const OrderItemModel(id: 'i3', dishName: 'Jareesh', quantity: 1, price: 22.0),
          const OrderItemModel(id: 'i4', dishName: 'Margog', quantity: 2, price: 21.0),
        ],
        totalAmount: 59.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deliveryAddress: 'Riyadh',
        notes: null,
      ),
    ]);

    // Active (accepted / preparing)
    _orders.addAll([
      OrderModel(
        id: '#2051',
        customerName: 'Ahmad Ali',
        customerImageUrl: null,
        items: [
          const OrderItemModel(id: 'i5', dishName: 'Jareesh', quantity: 2, price: 22.0),
          const OrderItemModel(id: 'i6', dishName: 'Margog', quantity: 1, price: 21.0),
        ],
        totalAmount: 64.0,
        status: OrderStatus.preparing,
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        deliveryAddress: 'Riyadh',
        notes: null,
      ),
      OrderModel(
        id: '#2050',
        customerName: 'Fatima Hassan',
        customerImageUrl: null,
        items: [
          const OrderItemModel(id: 'i7', dishName: 'Jareesh', quantity: 1, price: 22.0),
          const OrderItemModel(id: 'i8', dishName: 'Margog', quantity: 1, price: 21.0),
        ],
        totalAmount: 48.0,
        status: OrderStatus.accepted,
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        deliveryAddress: 'Riyadh',
        notes: null,
      ),
    ]);

    // Completed
    _orders.addAll([
      OrderModel(
        id: '#2045',
        customerName: 'Mohammed Ali',
        customerImageUrl: null,
        items: [
          const OrderItemModel(id: 'i9', dishName: 'Margog', quantity: 1, price: 21.0),
          const OrderItemModel(id: 'i10', dishName: 'Jareesh', quantity: 2, price: 22.0),
        ],
        totalAmount: 45.0,
        status: OrderStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        deliveryAddress: 'Riyadh',
        notes: null,
      ),
      OrderModel(
        id: '#2042',
        customerName: 'Nora Abdullah',
        customerImageUrl: null,
        items: [const OrderItemModel(id: 'i11', dishName: 'Margog', quantity: 1, price: 21.0)],
        totalAmount: 35.0,
        status: OrderStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        deliveryAddress: 'Riyadh',
        notes: null,
      ),
    ]);
  }

  @override
  Future<List<OrderModel>> getOrders({int? limit, int? offset}) async {
    await Future.delayed(AppConstants.mockDelay);
    final all = List<OrderModel>.from(_orders);
    final lim = (limit ?? 150).clamp(1, 500);
    final off = (offset ?? 0) < 0 ? 0 : (offset ?? 0);
    if (off >= all.length) return [];
    return all.skip(off).take(lim).toList();
  }

  @override
  Future<List<OrderModel>> getOrdersByStatus(
    OrderStatus status, {
    int? limit,
    int? offset,
  }) async {
    await Future.delayed(AppConstants.mockDelay);
    final filtered = _orders.where((order) => order.status == status).toList();
    final lim = (limit ?? 150).clamp(1, 500);
    final off = (offset ?? 0) < 0 ? 0 : (offset ?? 0);
    if (off >= filtered.length) return [];
    return filtered.skip(off).take(lim).toList();
  }

  @override
  Future<OrderModel> getOrderById(String id) async {
    await Future.delayed(AppConstants.mockDelay);
    final order = _orders.firstWhere(
      (order) => order.id == id,
      orElse: () => throw Exception('Order not found'),
    );
    return order;
  }

  @override
  Future<void> acceptOrder(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _orders.indexWhere((order) => order.id == id);
    if (index != -1) {
      _orders[index] = OrderModel(
        id: _orders[index].id,
        customerName: _orders[index].customerName,
        customerImageUrl: _orders[index].customerImageUrl,
        items: _orders[index].items,
        totalAmount: _orders[index].totalAmount,
        status: OrderStatus.accepted,
        createdAt: _orders[index].createdAt,
        deliveryAddress: _orders[index].deliveryAddress,
        notes: _orders[index].notes,
      );
    }
  }

  @override
  Future<void> rejectOrder(String id, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _orders.indexWhere((order) => order.id == id);
    if (index != -1) {
      _orders[index] = OrderModel(
        id: _orders[index].id,
        customerName: _orders[index].customerName,
        customerImageUrl: _orders[index].customerImageUrl,
        items: _orders[index].items,
        totalAmount: _orders[index].totalAmount,
        status: OrderStatus.rejected,
        createdAt: _orders[index].createdAt,
        deliveryAddress: _orders[index].deliveryAddress,
        notes: _orders[index].notes,
      );
    }
  }

  @override
  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _orders.indexWhere((order) => order.id == id);
    if (index != -1) {
      _orders[index] = OrderModel(
        id: _orders[index].id,
        customerName: _orders[index].customerName,
        customerImageUrl: _orders[index].customerImageUrl,
        items: _orders[index].items,
        totalAmount: _orders[index].totalAmount,
        status: status,
        createdAt: _orders[index].createdAt,
        deliveryAddress: _orders[index].deliveryAddress,
        notes: _orders[index].notes,
      );
    }
  }

  @override
  Stream<List<OrderModel>> watchOrders({List<OrderStatus>? statuses}) async* {
    await Future.delayed(AppConstants.mockDelay);
    List<OrderModel> list = List.from(_orders);
    if (statuses != null && statuses.isNotEmpty) {
      list = list.where((o) => statuses.contains(o.status)).toList();
    }
    yield list;
  }

  @override
  Future<ChefTodayStats> getTodayStats() async {
    await Future<void>.delayed(AppConstants.mockDelay);
    final bounds = LocalCalendarDayUtcBounds.forNow();
    var completedRev = 0.0;
    var completedCnt = 0;
    var kitchenCnt = 0;
    var pipelineVal = 0.0;
    for (final o in _orders) {
      final c = o.createdAt.toUtc();
      if (c.isBefore(bounds.startUtc) || !c.isBefore(bounds.endUtc)) continue;
      if (o.status == OrderStatus.completed) {
        completedRev += o.totalAmount;
        completedCnt++;
      }
      if (o.status == OrderStatus.pending ||
          o.status == OrderStatus.accepted ||
          o.status == OrderStatus.preparing ||
          o.status == OrderStatus.ready) {
        kitchenCnt++;
        pipelineVal += o.totalAmount;
      }
    }
    return ChefTodayStats(
      completedRevenueToday: completedRev,
      completedOrdersToday: completedCnt,
      inKitchenCountToday: kitchenCnt,
      pipelineOrderValueToday: pipelineVal,
    );
  }

  @override
  Future<List<OrderModel>> getDelayedOrders(Duration threshold) async {
    await Future.delayed(AppConstants.mockDelay);
    final cutoff = DateTime.now().subtract(threshold);
    return _orders.where((o) =>
        [OrderStatus.pending, OrderStatus.accepted, OrderStatus.preparing].contains(o.status) &&
        o.createdAt.isBefore(cutoff)).toList();
  }

  @override
  Future<List<OrderModel>> getCompletedOrdersSince(
    DateTime since, {
    int? limit,
  }) async {
    await Future.delayed(AppConstants.mockDelay);
    final lim = (limit ?? 500).clamp(1, 1000);
    return _orders
        .where((o) => o.status == OrderStatus.completed && !o.createdAt.isBefore(since))
        .take(lim)
        .toList();
  }

  @override
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
  }) async {
    await Future.delayed(AppConstants.mockDelay);
    return 'order_${DateTime.now().millisecondsSinceEpoch}';
  }
}
