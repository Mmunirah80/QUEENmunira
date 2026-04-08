import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:naham_cook_app/features/orders/data/models/order_model.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:naham_cook_app/features/orders/domain/entities/chef_today_stats.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';
import 'package:uuid/uuid.dart';

/// Shared in-memory store so customer, chef, and admin [OrderFlowFakeRemoteDataSource]
/// instances observe the same orders (sync contract).
@visibleForTesting
class OrderFlowSharedStore {
  OrderFlowSharedStore();

  final List<OrderModel> _orders = [];
  final Map<String, String> _idempotency = {};
  final Map<String, int> dishRemaining = {};
  final StreamController<List<OrderModel>> _bus = StreamController<List<OrderModel>>.broadcast(sync: true);

  List<OrderModel> get allOrders => List<OrderModel>.unmodifiable(_orders);

  void emit() {
    if (!_bus.isClosed) {
      _bus.add(List<OrderModel>.unmodifiable(_orders));
    }
  }

  Stream<List<OrderModel>> watchAll() async* {
    yield List<OrderModel>.unmodifiable(_orders);
    await for (final _ in _bus.stream) {
      yield List<OrderModel>.unmodifiable(_orders);
    }
  }

  int indexOf(String id) => _orders.indexWhere((o) => o.id == id);

  void addOrder(OrderModel o) {
    _orders.add(o);
    emit();
  }

  void replaceAt(int i, OrderModel o) {
    _orders[i] = o;
    emit();
  }

  String? existingIdForIdempotency(String customerId, String key) {
    return _idempotency['$customerId|$key'];
  }

  void rememberIdempotency(String customerId, String key, String orderId) {
    _idempotency['$customerId|$key'] = orderId;
  }

  /// Simulates platform / moderation system cancel (frozen account, etc.).
  void applySystemCancel(String orderId) {
    final i = indexOf(orderId);
    if (i < 0) throw StateError('unknown order $orderId');
    final o = _orders[i];
    _orders[i] = OrderModel(
      id: o.id,
      customerId: o.customerId,
      customerName: o.customerName,
      customerImageUrl: o.customerImageUrl,
      chefId: o.chefId,
      chefName: o.chefName,
      items: o.items,
      totalAmount: o.totalAmount,
      commissionAmount: o.commissionAmount,
      status: OrderStatus.cancelled,
      dbStatus: 'cancelled',
      cancelReason: OrderDbStatus.internalSystemCancelledFrozen,
      createdAt: o.createdAt,
      deliveryAddress: o.deliveryAddress,
      notes: o.notes,
      idempotencyKey: o.idempotencyKey,
    );
    emit();
  }
}

enum OrderFlowActorView { chef, customer, admin }

/// Deterministic fake [OrdersRemoteDataSource] for multi-role order flow tests.
/// Not used in production.
@visibleForTesting
class OrderFlowFakeRemoteDataSource implements OrdersRemoteDataSource {
  OrderFlowFakeRemoteDataSource({
    required this.view,
    required this.actorId,
    OrderFlowSharedStore? store,
  }) : store = store ?? OrderFlowSharedStore();

  final OrderFlowActorView view;
  final String actorId;
  final OrderFlowSharedStore store;

  List<OrderModel> _scoped() {
    switch (view) {
      case OrderFlowActorView.chef:
        return store.allOrders.where((o) => o.chefId == actorId).toList();
      case OrderFlowActorView.customer:
        return store.allOrders.where((o) => o.customerId == actorId).toList();
      case OrderFlowActorView.admin:
        return store.allOrders.toList();
    }
  }

  static bool isValidCookTransition(OrderStatus from, OrderStatus to) {
    if (from == to) return true;
    return switch ((from, to)) {
      (OrderStatus.pending, OrderStatus.accepted) => true,
      (OrderStatus.pending, OrderStatus.cancelled) => true,
      (OrderStatus.accepted, OrderStatus.preparing) => true,
      (OrderStatus.preparing, OrderStatus.ready) => true,
      (OrderStatus.ready, OrderStatus.completed) => true,
      (OrderStatus.accepted, OrderStatus.cancelled) => true,
      (OrderStatus.preparing, OrderStatus.cancelled) => true,
      (OrderStatus.ready, OrderStatus.cancelled) => true,
      _ => false,
    };
  }

  void _requireTransition(OrderStatus from, OrderStatus to) {
    if (!isValidCookTransition(from, to)) {
      throw StateError('invalid transition ${from.name} → ${to.name}');
    }
  }

  OrderModel _copy(
    OrderModel o, {
    OrderStatus? status,
    String? notes,
    String? cancelReason,
    String? dbStatus,
    String? idempotencyKey,
  }) {
    return OrderModel(
      id: o.id,
      customerId: o.customerId,
      customerName: o.customerName,
      customerImageUrl: o.customerImageUrl,
      chefId: o.chefId,
      chefName: o.chefName,
      items: o.items,
      totalAmount: o.totalAmount,
      commissionAmount: o.commissionAmount,
      status: status ?? o.status,
      dbStatus: dbStatus ?? o.dbStatus,
      cancelReason: cancelReason ?? o.cancelReason,
      createdAt: o.createdAt,
      deliveryAddress: o.deliveryAddress,
      notes: notes ?? o.notes,
      idempotencyKey: idempotencyKey ?? o.idempotencyKey,
    );
  }

  @override
  Future<List<OrderModel>> getOrders({int? limit, int? offset}) async {
    final all = _scoped();
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
    final filtered = _scoped().where((o) => o.status == status).toList();
    final lim = (limit ?? 150).clamp(1, 500);
    final off = (offset ?? 0) < 0 ? 0 : (offset ?? 0);
    if (off >= filtered.length) return [];
    return filtered.skip(off).take(lim).toList();
  }

  void _assertChefSession() {
    if (view != OrderFlowActorView.chef) {
      throw StateError('kitchen mutations only from chef session');
    }
  }

  void _assertChefCanMutate(OrderModel o) {
    if (o.chefId != actorId) {
      throw StateError('order not for this kitchen');
    }
  }

  @override
  Future<OrderModel> getOrderById(String id) async {
    final i = store.indexOf(id);
    if (i < 0) throw Exception('Order not found');
    final o = store.allOrders[i];
    if (view == OrderFlowActorView.customer && o.customerId != actorId) {
      throw Exception('Order not found');
    }
    if (view == OrderFlowActorView.chef && o.chefId != actorId) {
      throw Exception('Order not found');
    }
    return o;
  }

  @override
  Future<void> acceptOrder(String id) async {
    _assertChefSession();
    final i = store.indexOf(id);
    if (i < 0) throw StateError('unknown id');
    final row = store.allOrders[i];
    _assertChefCanMutate(row);
    if (row.status != OrderStatus.pending) {
      throw StateError('accept only when pending');
    }
    store.replaceAt(i, _copy(row, status: OrderStatus.accepted, dbStatus: 'accepted'));
  }

  @override
  Future<void> rejectOrder(String id, {String? reason}) async {
    _assertChefSession();
    final i = store.indexOf(id);
    if (i < 0) throw StateError('unknown id');
    final row = store.allOrders[i];
    _assertChefCanMutate(row);
    if (row.status != OrderStatus.pending) throw StateError('reject only when pending');
    final note = reason != null && reason.trim().isNotEmpty ? reason.trim() : row.notes;
    store.replaceAt(
      i,
      _copy(
        row,
        status: OrderStatus.cancelled,
        dbStatus: 'cancelled_by_cook',
        cancelReason: OrderDbStatus.internalCookRejected,
        notes: note,
      ),
    );
  }

  @override
  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    _assertChefSession();
    final i = store.indexOf(id);
    if (i < 0) throw Exception('Order not found');
    final row = store.allOrders[i];
    _assertChefCanMutate(row);
    final from = row.status;
    _requireTransition(from, status);
    store.replaceAt(i, _copy(row, status: status, dbStatus: OrderDbStatus.mutationValueFor(status)));
  }

  /// Customer-initiated cancel while order is still waiting (pending).
  Future<void> customerCancelPending(String orderId) async {
    if (view != OrderFlowActorView.customer) {
      throw StateError('customerCancelPending only on customer datasource');
    }
    final i = store.indexOf(orderId);
    if (i < 0) throw Exception('Order not found');
    final o = store.allOrders[i];
    if (o.customerId != actorId) throw StateError('not your order');
    if (o.status != OrderStatus.pending) throw StateError('only pending can be cancelled by customer');
    store.replaceAt(
      i,
      _copy(o, status: OrderStatus.cancelled, dbStatus: 'cancelled_by_customer'),
    );
  }

  @override
  Stream<List<OrderModel>> watchOrders({List<OrderStatus>? statuses}) {
    return store.watchAll().map((all) {
      var list = view == OrderFlowActorView.chef
          ? all.where((o) => o.chefId == actorId).toList()
          : view == OrderFlowActorView.customer
              ? all.where((o) => o.customerId == actorId).toList()
              : all;
      if (statuses != null && statuses.isNotEmpty) {
        list = list.where((o) => statuses.contains(o.status)).toList();
      }
      return list;
    });
  }

  @override
  Future<ChefTodayStats> getTodayStats() async {
    return const ChefTodayStats(
      completedRevenueToday: 0,
      completedOrdersToday: 0,
      inKitchenCountToday: 0,
      pipelineOrderValueToday: 0,
    );
  }

  @override
  Future<List<OrderModel>> getDelayedOrders(Duration threshold) async => [];

  @override
  Future<List<OrderModel>> getCompletedOrdersSince(
    DateTime since, {
    int? limit,
  }) async {
    final lim = (limit ?? 500).clamp(1, 1000);
    return _scoped()
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
    double commissionAmount = 0,
    String? deliveryAddress,
    String? notes,
    String? idempotencyKey,
  }) async {
    if (customerId.trim().isEmpty || chefId.trim().isEmpty) {
      throw ArgumentError('customerId and chefId are required');
    }
    if (customerName.trim().isEmpty) {
      throw ArgumentError('customerName must not be empty');
    }
    if (items.isEmpty) {
      throw ArgumentError('At least one line item is required');
    }
    if (totalAmount.isNaN || totalAmount < 0) {
      throw ArgumentError('Invalid total');
    }

    final idem = idempotencyKey?.trim();
    if (idem != null && idem.isNotEmpty) {
      final existing = store.existingIdForIdempotency(customerId, idem);
      if (existing != null) return existing;
    }

    for (final item in items) {
      final dishId = (item['id'] as String?) ?? (item['dishId'] as String?);
      final qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 1;
      if (dishId != null && dishId.isNotEmpty && store.dishRemaining.containsKey(dishId)) {
        final rem = store.dishRemaining[dishId] ?? 0;
        if (qty > rem) {
          throw Exception(rem <= 0 ? 'This dish is sold out' : 'Only $rem available');
        }
      }
    }

    for (final item in items) {
      final dishId = (item['id'] as String?) ?? (item['dishId'] as String?);
      final qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 1;
      if (dishId != null && dishId.isNotEmpty && store.dishRemaining.containsKey(dishId)) {
        final rem = store.dishRemaining[dishId] ?? 0;
        store.dishRemaining[dishId] = rem - qty;
      }
    }

    const uuid = Uuid();
    final id = uuid.v4();
    final mappedItems = <OrderItemModel>[];
    for (final m in items) {
      mappedItems.add(
        OrderItemModel(
          id: uuid.v4(),
          dishName: (m['name'] ?? m['dish_name'] ?? 'Item').toString(),
          quantity: (m['quantity'] is num) ? (m['quantity'] as num).toInt() : 1,
          price: (m['price'] is num) ? (m['price'] as num).toDouble() : 0,
        ),
      );
    }

    store.addOrder(
      OrderModel(
        id: id,
        customerId: customerId,
        customerName: customerName,
        chefId: chefId,
        chefName: chefName,
        items: mappedItems,
        totalAmount: totalAmount,
        commissionAmount: commissionAmount,
        status: OrderStatus.pending,
        dbStatus: 'pending',
        createdAt: DateTime.now(),
        deliveryAddress: deliveryAddress,
        notes: notes,
        idempotencyKey: idem,
      ),
    );

    if (idem != null && idem.isNotEmpty) {
      store.rememberIdempotency(customerId, idem, id);
    }
    return id;
  }
}

/// Throws once on [getOrders] then delegates (network flake simulation).
@visibleForTesting
class OrdersNetworkFailOnceWrapper implements OrdersRemoteDataSource {
  OrdersNetworkFailOnceWrapper(this._inner);

  final OrdersRemoteDataSource _inner;
  bool failNextGetOrders = true;

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
    return _inner.createOrder(
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

  @override
  Future<void> acceptOrder(String id) => _inner.acceptOrder(id);

  @override
  Future<List<OrderModel>> getCompletedOrdersSince(
    DateTime since, {
    int? limit,
  }) =>
      _inner.getCompletedOrdersSince(since, limit: limit);

  @override
  Future<ChefTodayStats> getTodayStats() => _inner.getTodayStats();

  @override
  Future<List<OrderModel>> getDelayedOrders(Duration threshold) => _inner.getDelayedOrders(threshold);

  @override
  Future<OrderModel> getOrderById(String id) => _inner.getOrderById(id);

  @override
  Future<List<OrderModel>> getOrders({int? limit, int? offset}) async {
    if (failNextGetOrders) {
      failNextGetOrders = false;
      throw Exception('Simulated network failure');
    }
    return _inner.getOrders(limit: limit, offset: offset);
  }

  @override
  Future<List<OrderModel>> getOrdersByStatus(
    OrderStatus status, {
    int? limit,
    int? offset,
  }) =>
      _inner.getOrdersByStatus(status, limit: limit, offset: offset);

  @override
  Future<void> rejectOrder(String id, {String? reason}) => _inner.rejectOrder(id, reason: reason);

  @override
  Future<void> updateOrderStatus(String id, OrderStatus status) => _inner.updateOrderStatus(id, status);

  @override
  Stream<List<OrderModel>> watchOrders({List<OrderStatus>? statuses}) =>
      _inner.watchOrders(statuses: statuses);
}
