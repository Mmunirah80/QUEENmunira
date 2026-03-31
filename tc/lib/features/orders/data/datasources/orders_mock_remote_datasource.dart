import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/local_calendar_day_utc_bounds.dart';
import '../../domain/entities/chef_today_stats.dart';
import '../../domain/entities/order_entity.dart';
import '../models/order_model.dart';
import 'orders_remote_datasource.dart';

/// Stable UUID strings so Postgres `uuid` columns (e.g. `conversations.order_id`) work with mock orders.
abstract class CookMockOrderIds {
  CookMockOrderIds._();

  static const pendingAlpha = 'f0000001-0000-4000-8000-000000000001';
  static const pendingBeta = 'f0000002-0000-4000-8000-000000000002';
  static const pendingGamma = 'f0000008-0000-4000-8000-000000000008';
  static const pendingDelta = 'f0000009-0000-4000-8000-000000000009';
  static const activeAccepted = 'f0000003-0000-4000-8000-000000000003';
  static const activePreparing = 'f0000004-0000-4000-8000-000000000004';
  static const activeReady = 'f0000005-0000-4000-8000-000000000005';
  static const doneCompleted = 'f0000006-0000-4000-8000-000000000006';
  static const doneCancelled = 'f0000007-0000-4000-8000-000000000007';

  static const customerA = 'e1000001-0000-4000-8000-0000000000a1';
  static const customerB = 'e1000002-0000-4000-8000-0000000000a2';
  static const customerC = 'e1000003-0000-4000-8000-0000000000a3';
  static const customerD = 'e1000004-0000-4000-8000-0000000000a4';
  static const customerE = 'e1000005-0000-4000-8000-0000000000a5';
  static const customerF = 'e1000006-0000-4000-8000-0000000000a6';
  static const customerG = 'e1000007-0000-4000-8000-0000000000a7';
  static const customerH = 'e1000008-0000-4000-8000-0000000000a8';
  static const customerI = 'e1000009-0000-4000-8000-0000000000a9';

  static const lineA1 = 'd1000001-0000-4000-8000-000000000001';
  static const lineB1 = 'd1000002-0000-4000-8000-000000000002';
  static const lineC1 = 'd1000003-0000-4000-8000-000000000003';
  static const lineD1 = 'd1000004-0000-4000-8000-000000000004';
  static const lineE1 = 'd1000005-0000-4000-8000-000000000005';
  static const lineF1 = 'd1000006-0000-4000-8000-000000000006';
  static const lineG1 = 'd1000007-0000-4000-8000-000000000007';
  static const lineH1 = 'd1000008-0000-4000-8000-000000000008';
  static const lineI1 = 'd1000009-0000-4000-8000-000000000009';
}

/// In-memory orders for cook QA (timeline, tabs, accept → … → complete, reject).
///
/// **Debug default:** mock is ON so `flutter run` works without flags.
/// Enable with `--dart-define=COOK_MOCK_ORDERS=true` (debug). Real Supabase is the default.
///
/// One instance per [chefId] so [ordersRepositoryProvider] rebuilds (e.g. auth ticks)
/// do not reset seeded rows or drop in-flight mutations.
class OrdersMockRemoteDataSource implements OrdersRemoteDataSource {
  static final Map<String, OrdersMockRemoteDataSource> _instancesByChefId = {};

  /// Clears cached instances (closes broadcast buses). Call from tests between cases.
  @visibleForTesting
  static void clearInstancesForTests() {
    for (final ds in _instancesByChefId.values) {
      if (!ds._bus.isClosed) {
        ds._bus.close();
      }
    }
    _instancesByChefId.clear();
  }

  factory OrdersMockRemoteDataSource({required String chefId}) {
    return _instancesByChefId.putIfAbsent(
      chefId,
      () => OrdersMockRemoteDataSource._internal(chefId: chefId),
    );
  }

  OrdersMockRemoteDataSource._internal({required String chefId}) : _chefId = chefId {
    _seed();
  }

  final String _chefId;
  final StreamController<List<OrderModel>> _bus =
      StreamController<List<OrderModel>>.broadcast(sync: true);
  List<OrderModel> _rows = [];
  final Map<String, String> _createOrderIdempotency = {};

  void _seed() {
    if (_rows.isNotEmpty) return;
    final now = DateTime.now();
    _rows = [
      // ── New tab: exercise accept / reject ─────────────────────────────
      OrderModel(
        id: CookMockOrderIds.pendingAlpha,
        customerId: CookMockOrderIds.customerA,
        customerName: 'Customer A · full flow',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineA1,
            dishName: 'Grilled plate',
            quantity: 2,
            price: 40,
          ),
        ],
        totalAmount: 80,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 3)),
        deliveryAddress: 'Riyadh — mock',
        notes: '[MOCK] Accept → Start preparing → Ready → Complete',
      ),
      OrderModel(
        id: CookMockOrderIds.pendingBeta,
        customerId: CookMockOrderIds.customerB,
        customerName: 'Customer B · reject',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineB1,
            dishName: 'Salad bowl',
            quantity: 1,
            price: 22,
          ),
        ],
        totalAmount: 22,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 8)),
        deliveryAddress: 'Jeddah — mock',
        notes: '[MOCK] Try Reject from New tab',
      ),
      OrderModel(
        id: CookMockOrderIds.pendingGamma,
        customerId: CookMockOrderIds.customerH,
        customerName: 'Customer H · multi-queue A',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineH1,
            dishName: 'Kabsa plate',
            quantity: 1,
            price: 55,
          ),
        ],
        totalAmount: 55,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 1)),
        deliveryAddress: 'Riyadh — mock',
        notes: '[MOCK] Extra New-tab row for accept/reject flow QA',
      ),
      OrderModel(
        id: CookMockOrderIds.pendingDelta,
        customerId: CookMockOrderIds.customerI,
        customerName: 'Customer I · multi-queue B',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineI1,
            dishName: 'Juice + sandwich',
            quantity: 2,
            price: 15,
          ),
        ],
        totalAmount: 30,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 12)),
        deliveryAddress: 'Dammam — mock',
        notes: '[MOCK] Extra New-tab row for accept/reject flow QA',
      ),
      // ── Active tab: one row per timeline step (read + advance) ────────
      OrderModel(
        id: CookMockOrderIds.activeAccepted,
        customerId: CookMockOrderIds.customerC,
        customerName: 'Customer C · accepted',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineC1,
            dishName: 'Burger combo',
            quantity: 1,
            price: 35,
          ),
        ],
        totalAmount: 35,
        status: OrderStatus.accepted,
        createdAt: now.subtract(const Duration(minutes: 15)),
        deliveryAddress: 'Dammam — mock',
        notes: '[MOCK] Next: Start preparing',
      ),
      OrderModel(
        id: CookMockOrderIds.activePreparing,
        customerId: CookMockOrderIds.customerD,
        customerName: 'Customer D · preparing',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineD1,
            dishName: 'Pasta',
            quantity: 2,
            price: 28,
          ),
        ],
        totalAmount: 56,
        status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 22)),
        deliveryAddress: 'Khobar — mock',
        notes: '[MOCK] Next: Mark ready',
      ),
      OrderModel(
        id: CookMockOrderIds.activeReady,
        customerId: CookMockOrderIds.customerE,
        customerName: 'Customer E · ready',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineE1,
            dishName: 'Soup + bread',
            quantity: 1,
            price: 18,
          ),
        ],
        totalAmount: 18,
        status: OrderStatus.ready,
        createdAt: now.subtract(const Duration(minutes: 28)),
        deliveryAddress: 'Taif — mock',
        notes: '[MOCK] Next: Complete',
      ),
      // ── Completed / Cancelled (read-only timeline) ─────────────────────
      OrderModel(
        id: CookMockOrderIds.doneCompleted,
        customerId: CookMockOrderIds.customerF,
        customerName: 'Customer F · done',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineF1,
            dishName: 'Dessert box',
            quantity: 1,
            price: 45,
          ),
        ],
        totalAmount: 45,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(hours: 2)),
        deliveryAddress: 'Abha — mock',
        notes: '[MOCK] Completed — no further actions',
      ),
      OrderModel(
        id: CookMockOrderIds.doneCancelled,
        customerId: CookMockOrderIds.customerG,
        customerName: 'Customer G · cancelled',
        chefId: _chefId,
        chefName: 'Your kitchen',
        items: const [
          OrderItemModel(
            id: CookMockOrderIds.lineG1,
            dishName: 'Cancelled order sample',
            quantity: 1,
            price: 12,
          ),
        ],
        totalAmount: 12,
        status: OrderStatus.cancelled,
        createdAt: now.subtract(const Duration(hours: 5)),
        deliveryAddress: '—',
        notes: '[MOCK] Cancelled row — Cook unavailable',
      ),
    ];
    _emit();
  }

  void _emit() {
    if (!_bus.isClosed) {
      _bus.add(List<OrderModel>.unmodifiable(_rows));
    }
  }

  List<OrderModel> _filter(List<OrderStatus>? statuses) {
    if (statuses == null || statuses.isEmpty) return List<OrderModel>.from(_rows);
    return _rows.where((o) => statuses.contains(o.status)).toList();
  }

  int _indexOf(String id) => _rows.indexWhere((o) => o.id == id);

  OrderModel _copy(OrderModel o, {OrderStatus? status, String? notes}) {
    return OrderModel(
      id: o.id,
      customerId: o.customerId,
      customerName: o.customerName,
      customerImageUrl: o.customerImageUrl,
      chefId: o.chefId,
      chefName: o.chefName,
      items: o.items,
      totalAmount: o.totalAmount,
      status: status ?? o.status,
      createdAt: o.createdAt,
      deliveryAddress: o.deliveryAddress,
      notes: notes ?? o.notes,
    );
  }

  /// Mirrors server rules: only sensible cook-facing transitions (plus cancel from kitchen).
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
      throw StateError(
        'Mock orders: invalid transition ${from.name} → ${to.name} '
        '(aligns with production transition rules).',
      );
    }
  }

  @override
  Stream<List<OrderModel>> watchOrders({List<OrderStatus>? statuses}) {
    return () async* {
      // Do not emit [] first: Riverpod/UI often sticks on the first snapshot and shows "empty".
      _seed();
      yield _filter(statuses);
      await for (final _ in _bus.stream) {
        yield _filter(statuses);
      }
    }();
  }

  @override
  Future<void> acceptOrder(String id) async {
    final i = _indexOf(id);
    if (i < 0) throw StateError('Mock orders: unknown id $id');
    final cur = _rows[i].status;
    if (cur != OrderStatus.pending) {
      throw StateError(
        'Mock orders: accept only when pending (current: ${cur.name})',
      );
    }
    _rows[i] = _copy(_rows[i], status: OrderStatus.accepted);
    debugPrint('[OrdersMock] acceptOrder $id -> accepted');
    _emit();
  }

  @override
  Future<void> rejectOrder(String id, {String? reason}) async {
    final i = _indexOf(id);
    if (i < 0) throw StateError('Mock orders: unknown id $id');
    final cur = _rows[i].status;
    if (cur != OrderStatus.pending) {
      throw StateError(
        'Mock orders: reject only when pending (current: ${cur.name})',
      );
    }
    final note = reason != null && reason.trim().isNotEmpty
        ? reason.trim()
        : _rows[i].notes;
    _rows[i] = _copy(_rows[i], status: OrderStatus.cancelled, notes: note);
    debugPrint('[OrdersMock] rejectOrder $id -> cancelled (chef decline)');
    _emit();
  }

  @override
  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    final i = _indexOf(id);
    if (i < 0) {
      throw Exception('Order not found (mock)');
    }
    final from = _rows[i].status;
    _requireTransition(from, status);
    _rows[i] = _copy(_rows[i], status: status);
    debugPrint('[OrdersMock] updateOrderStatus $id $from -> $status');
    _emit();
  }

  @override
  Future<List<OrderModel>> getOrders({int? limit, int? offset}) async {
    final all = List<OrderModel>.from(_rows);
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
    final filtered = _rows.where((o) => o.status == status).toList();
    final lim = (limit ?? 150).clamp(1, 500);
    final off = (offset ?? 0) < 0 ? 0 : (offset ?? 0);
    if (off >= filtered.length) return [];
    return filtered.skip(off).take(lim).toList();
  }

  @override
  Future<OrderModel> getOrderById(String id) async {
    final i = _indexOf(id);
    if (i < 0) throw Exception('Order not found');
    return _rows[i];
  }

  @override
  Future<ChefTodayStats> getTodayStats() async {
    final bounds = LocalCalendarDayUtcBounds.forNow();
    var completedRev = 0.0;
    var completedCnt = 0;
    var kitchenCnt = 0;
    var pipelineVal = 0.0;
    for (final o in _rows) {
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
  Future<List<OrderModel>> getDelayedOrders(Duration threshold) async => [];

  @override
  Future<List<OrderModel>> getCompletedOrdersSince(
    DateTime since, {
    int? limit,
  }) async {
    final lim = (limit ?? 500).clamp(1, 1000);
    return _rows
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
    final idem = idempotencyKey?.trim();
    if (idem != null && idem.isNotEmpty) {
      final existing = _createOrderIdempotency[idem];
      if (existing != null) return existing;
    }
    const uuid = Uuid();
    final id = uuid.v4();
    final now = DateTime.now();
    final mappedItems = <OrderItemModel>[];
    for (var k = 0; k < items.length; k++) {
      final m = items[k];
      mappedItems.add(
        OrderItemModel(
          id: uuid.v4(),
          dishName: (m['name'] ?? m['dish_name'] ?? 'Item').toString(),
          quantity: (m['quantity'] is num) ? (m['quantity'] as num).toInt() : 1,
          price: (m['price'] is num) ? (m['price'] as num).toDouble() : 0,
        ),
      );
    }
    _rows.add(
      OrderModel(
        id: id,
        customerId: customerId,
        customerName: customerName,
        chefId: chefId,
        chefName: chefName,
        items: mappedItems,
        totalAmount: totalAmount,
        status: OrderStatus.pending,
        createdAt: now,
        deliveryAddress: deliveryAddress,
        notes: notes ?? '[MOCK] Created in-memory',
      ),
    );
    _emit();
    debugPrint('[OrdersMock] createOrder -> $id');
    if (idem != null && idem.isNotEmpty) {
      _createOrderIdempotency[idem] = id;
    }
    return id;
  }
}
