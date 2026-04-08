import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/supabase_auth_user_id.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../orders/data/datasources/orders_datasource_exceptions.dart';
import '../../../orders/data/order_db_status.dart';
import '../../../orders/data/order_supabase_hydration.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/data/models/order_model.dart';

/// Supabase orders + order_items for customer: create order, watch by customer, watch single, expire timeout.
/// Tables: orders (id, customer_id, chef_id, status, total_amount, commission_amount, notes,
///         delivery_address, customer_name, chef_name, created_at, updated_at)
///         order_items (id, order_id, menu_item_id or dish_id, quantity, unit_price)
class CustomerOrdersSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.dataClient;

  /// `supabase_flutter` RPC returns the decoded JSON body directly (Map/List), not a `.data` wrapper.
  static Map<String, dynamic> _rpcBodyToMap(dynamic res) {
    if (res == null) return <String, dynamic>{};
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is List && res.isNotEmpty) {
      final first = res.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return <String, dynamic>{};
  }

  Future<String?> _findExistingOrderByIdempotency({
    required String customerId,
    required String idempotencyKey,
  }) async {
    final existing = await _sb
        .from('orders')
        .select('id')
        .eq('customer_id', customerId)
        .eq('idempotency_key', idempotencyKey)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final existingId = existing?['id'] as String?;
    if (existingId == null || existingId.isEmpty) return null;
    return existingId;
  }

  Future<({bool ok, int remaining})> _tryDecreaseRemainingQuantity({
    required String dishId,
    required int quantity,
  }) async {
    final res = await _sb.rpc<dynamic>(
      'decrease_remaining_quantity',
      params: {
        'p_dish_id': dishId,
        'p_quantity': quantity,
      },
    );

    final map = _rpcBodyToMap(res);

    final ok = map['ok'] as bool? ?? false;
    final remaining = (map['remaining_quantity'] as num?)?.toInt() ??
        (map['remaining'] as num?)?.toInt() ??
        0;
    return (ok: ok, remaining: remaining);
  }

  Future<void> _increaseRemainingQuantity({
    required String dishId,
    required int quantity,
  }) async {
    await _sb.rpc<dynamic>(
      'increase_remaining_quantity',
      params: {
        'p_dish_id': dishId,
        'p_quantity': quantity,
      },
    );
  }

  /// Best-effort restore after failed create; retries reduce transient network drift.
  Future<void> _increaseRemainingQuantityWithRetry({
    required String dishId,
    required int quantity,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _increaseRemainingQuantity(dishId: dishId, quantity: quantity);
        return;
      } catch (e, st) {
        lastError = e;
        debugPrint(
          '[CustomerOrdersSupabase] increase_remaining_quantity attempt ${attempt + 1}/3 dishId=$dishId: $e\n$st',
        );
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        }
      }
    }
    Error.throwWithStackTrace(
      lastError ?? Exception('increase_remaining_quantity failed'),
      StackTrace.current,
    );
  }

  /// Creates an order and its order_items. Commission already included in total_amount.
  /// Returns the new order id.
  Future<String> createOrder({
    required String customerId,
    required String customerName,
    required String chefId,
    required String chefName,
    required String idempotencyKey,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double commissionAmount,
    String? deliveryAddress,
    String? notes,
  }) async {
    // Fast-path retry safety: if an order was already created with this key,
    // return it before doing any mutable operations (stock/order_items/etc).
    final existingOrderId = await _findExistingOrderByIdempotency(
      customerId: customerId,
      idempotencyKey: idempotencyKey,
    );
    if (existingOrderId != null) {
      debugPrint('[CustomerOrdersSupabase] Reusing existing order by idempotency key: $existingOrderId');
      return existingOrderId;
    }

    final validItems = <Map<String, dynamic>>[];
    for (final item in items) {
      final dishId = (item['id'] as String?) ?? (item['dishId'] as String?);
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      if (dishId == null || dishId.isEmpty || qty <= 0) continue;
      validItems.add(item);
    }
    if (validItems.isEmpty) {
      throw ArgumentError(
        'No valid line items (each needs a dish id and quantity >= 1)',
      );
    }

    const uuid = Uuid();
    final orderId = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    // Status must match DB enum: pending, accepted, preparing, ready, completed, cancelled,
    // paid_waiting_acceptance, cancelled_by_customer, cancelled_by_cook, cancelled_payment_failed, expired, rejected
    // Use 'pending' for new orders (safest value).
    const status = 'pending';
    if (kDebugMode) {
      debugPrint(
        '[CustomerOrdersSupabase] createOrder start customer=$customerId chef=$chefId items=${validItems.length}',
      );
    }
    final orderPayload = {
      'id': orderId,
      'customer_id': customerId,
      'chef_id': chefId,
      'idempotency_key': idempotencyKey,
      'status': status,
      'total_amount': totalAmount,
      'commission_amount': commissionAmount,
      'notes': notes,
      'delivery_address': deliveryAddress,
      'customer_name': customerName,
      'chef_name': chefName,
      'created_at': now,
      'updated_at': now,
    };
    debugPrint('[CustomerOrdersSupabase] Order payload: $orderPayload');
    final orderItems = validItems.map<Map<String, dynamic>>((e) {
      final itemId = uuid.v4();
      final dishId = e['id'] as String? ?? e['dishId'] as String?;
      final row = {
        'id': itemId,
        'order_id': orderId,
        // If your schema uses dish_id instead of menu_item_id, adjust here.
        'menu_item_id': dishId,
        'dish_name': e['dishName'] as String? ?? '',
        'quantity': (e['quantity'] as num?)?.toInt() ?? 1,
        'unit_price': ((e['price'] as num?)?.toDouble()) ?? 0.0,
      };
      return row;
    }).toList();
    debugPrint('[CustomerOrdersSupabase] order_items payload (${orderItems.length} items): $orderItems');
    final decremented = <({String dishId, int quantity})>[];
    var orderInserted = false;
    try {
      // Decrease remaining quantities first (atomic on DB side) to prevent overselling.
      // We will restore if order insert fails.
      for (final item in validItems) {
        // [validItems] only contains rows with non-empty dish id and qty >= 1.
        final dishId =
            ((item['id'] as String?) ?? (item['dishId'] as String?))!;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;

        if (kDebugMode) {
          debugPrint(
            '[QuantityCheck] decrease dishId=$dishId qty=$qty chefId=$chefId',
          );
        }
        final dec = await _tryDecreaseRemainingQuantity(dishId: dishId, quantity: qty);
        if (kDebugMode) {
          debugPrint(
            '[QuantityCheck] result dishId=$dishId ok=${dec.ok} remaining=${dec.remaining}',
          );
        }

        if (!dec.ok) {
          // Restore already decremented stock for this customer order group.
          for (final d in decremented) {
            await _increaseRemainingQuantity(dishId: d.dishId, quantity: d.quantity);
          }
          decremented.clear();

          throw Exception(
            dec.remaining <= 0 ? 'This dish is sold out' : 'Only ${dec.remaining} available',
          );
        }

        decremented.add((dishId: dishId, quantity: qty));
      }

      debugPrint('[CustomerOrdersSupabase] Inserting order id=$orderId ...');
      await _sb.from('orders').insert(orderPayload);
      orderInserted = true;
      debugPrint('[CustomerOrdersSupabase] Order inserted id=$orderId');
      if (orderItems.isNotEmpty) {
        debugPrint(
          '[CustomerOrdersSupabase] Inserting ${orderItems.length} order_items for orderId=$orderId',
        );
        await _sb.from('order_items').insert(orderItems);
        debugPrint('[CustomerOrdersSupabase] order_items inserted for orderId=$orderId');
      }
      debugPrint('[CustomerOrdersSupabase] ORDER CREATED: $orderId');
    } catch (e, st) {
      // Restore stock if we already decremented but order insert failed.
      if (decremented.isNotEmpty) {
        for (final d in decremented) {
          try {
            await _increaseRemainingQuantityWithRetry(
              dishId: d.dishId,
              quantity: d.quantity,
            );
          } catch (_) {
            // Non-fatal: better to preserve the order error than hide a restoration error.
            debugPrint(
              '[QuantityCheck][RestoreOnCreateOrderFailure] failed for dishId=${d.dishId}',
            );
          }
        }
      }

      if (orderInserted) {
        try {
          await _sb.from('orders').delete().eq('id', orderId);
        } catch (_) {
          // Non-fatal; restoration is already attempted.
        }
      }

      debugPrint('[CustomerOrdersSupabase] Order insert error: $e');
      debugPrint('[CustomerOrdersSupabase] FULL error: $e');
      debugPrint('[CustomerOrdersSupabase] stackTrace: $st');
      if (e is PostgrestException) {
        debugPrint('[CustomerOrdersSupabase] PostgrestException: message=${e.message}, code=${e.code}, details=${e.details}');
        // Unique-violation retry path: fetch and reuse existing order created
        // by a previous request with the same idempotency_key.
        if (e.code == '23505') {
          final existingId = await _findExistingOrderByIdempotency(
            customerId: customerId,
            idempotencyKey: idempotencyKey,
          );
          if (existingId != null) {
            debugPrint('[CustomerOrdersSupabase] Duplicate idempotency key detected, reusing order id=$existingId');
            return existingId;
          }
        }
      }
      rethrow;
    }
    return orderId;
  }

  Stream<List<OrderModel>> watchOrdersByCustomerId(String customerId) {
    if (kDebugMode) {
      debugPrint('[CustomerOrdersSupabase] watchOrders customerId=$customerId');
    }
    if (customerId.isEmpty) {
      return Stream.value(const <OrderModel>[]);
    }
    return _sb
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .asyncMap((rows) => _ordersWithItems(rows))
        .handleError(
          (Object e, StackTrace st) =>
              ordersDataSourceRethrowMapped(e, st, 'watchOrdersByCustomerId'),
        );
  }

  Stream<List<OrderModel>> watchActiveOrders(String customerId) {
    return watchOrdersByCustomerId(customerId).map((list) {
      return list
          .where(
            (o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.accepted ||
                o.status == OrderStatus.preparing ||
                o.status == OrderStatus.ready,
          )
          .toList();
    });
  }

  Stream<List<OrderModel>> watchCompletedOrders(String customerId) {
    return watchOrdersByCustomerId(customerId).map(
      (list) => list.where((o) => o.status == OrderStatus.completed).toList(),
    );
  }

  Stream<List<OrderModel>> watchCancelledOrders(String customerId) {
    return watchOrdersByCustomerId(customerId).map(
      (list) => list
          .where(
            (o) => o.status == OrderStatus.cancelled || o.status == OrderStatus.rejected,
          )
          .toList(),
    );
  }

  Stream<OrderModel?> watchOrderById(String orderId) {
    return _sb
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          final list = await _ordersWithItems(rows);
          return list.isNotEmpty ? list.first : null;
        })
        .handleError(
          (Object e, StackTrace st) =>
              ordersDataSourceRethrowMapped(e, st, 'watchOrderById'),
        );
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    final row = await _sb.from('orders').select().eq('id', orderId).maybeSingle();
    if (row == null) return null;
    final list = await _ordersWithItems([row]);
    return list.isNotEmpty ? list.first : null;
  }

  /// Customer-side transitions via [transition_order_status].
  /// Customers may only trigger **system** cancellations (`system_cancelled_frozen`) with
  /// [customerSystemCancel] — used for acceptance-timeout and payment-failure rollback (not a user "cancel" button).
  Future<void> _customerTransitionOrderStatus(
    String orderId,
    String newStatus, {
    String? cancelReason,
    bool customerSystemCancel = false,
  }) async {
    final current = await _sb
        .from('orders')
        .select('updated_at')
        .eq('id', orderId)
        .maybeSingle();
    final expectedUpdatedAt = current?['updated_at']?.toString();
    await _sb.rpc<dynamic>(
      'transition_order_status',
      params: {
        'order_id': orderId,
        'new_status': newStatus,
        'expected_updated_at': expectedUpdatedAt,
        if (cancelReason != null) 'cancel_reason': cancelReason,
        'customer_system_cancel': customerSystemCancel,
      },
    );
  }

  /// Timeout safeguard: move waiting orders to unified `cancelled` + system reason via backend.
  Future<void> expireOrderByTimeout(String orderId) async {
    await _customerTransitionOrderStatus(
      orderId,
      'cancelled',
      cancelReason: OrderDbStatus.internalSystemCancelledFrozen,
      customerSystemCancel: true,
    );
  }

  /// Rolls back a **pending** order after a failed payment / checkout attempt (all-or-nothing checkout).
  /// This is not a discretionary customer cancel — it uses the same system reason as automated timeouts.
  Future<void> cancelPendingOrderAfterPaymentFailure(String orderId) async {
    final uid = supabaseAuthUserId(_sb);
    if (uid == null || uid.isEmpty) {
      throw Exception('Not signed in');
    }
    final row = await _sb
        .from('orders')
        .select('customer_id,status')
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) {
      throw Exception('Order not found');
    }
    if ((row['customer_id']?.toString() ?? '') != uid) {
      throw Exception('Not your order');
    }
    final s = (row['status']?.toString() ?? '').trim();
    if (!OrderDbStatus.pending.contains(s)) {
      throw Exception('Only waiting orders can be voided after a failed checkout');
    }
    await _customerTransitionOrderStatus(
      orderId,
      'cancelled',
      cancelReason: OrderDbStatus.internalSystemCancelledFrozen,
      customerSystemCancel: true,
    );
  }

  /// Live kitchen names keyed by chef id (from `chef_profiles`). Used so order cards match browse UI
  /// and are not stuck on stale/wrong `orders.chef_name`.
  Future<Map<String, String>> _fetchKitchenNamesByChefIds(Set<String> chefIds) async {
    if (chefIds.isEmpty) return {};
    final ids = chefIds.toList();
    final out = <String, String>{};
    const chunk = 80;
    for (var i = 0; i < ids.length; i += chunk) {
      final end = i + chunk > ids.length ? ids.length : i + chunk;
      final slice = ids.sublist(i, end);
      try {
        final res = await _sb.from('chef_profiles').select('id,kitchen_name').inFilter('id', slice);
        for (final row in res as List) {
          final m = Map<String, dynamic>.from(row as Map);
          final id = m['id']?.toString() ?? '';
          final name = (m['kitchen_name'] as String?)?.trim() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) out[id] = name;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[CustomerOrdersSupabase] kitchen_name batch fetch failed: $e\n$st');
        }
      }
    }
    return out;
  }

  String? _resolveChefDisplayName({
    required Map<String, String> kitchenByChefId,
    required String? chefId,
    required String? orderChefName,
  }) {
    final cid = chefId?.trim();
    if (cid != null && cid.isNotEmpty) {
      final fromProfile = kitchenByChefId[cid];
      if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    }
    final fromOrder = orderChefName?.trim();
    if (fromOrder != null && fromOrder.isNotEmpty) return fromOrder;
    return null;
  }

  OrderModel? _orderFromRowData(
    Map<String, dynamic> r,
    Map<String, String> kitchenByChefId,
    List<OrderItemEntity> items,
  ) {
    final id = r['id'] as String?;
    if (id == null) return null;
    final rawStatus = r['status']?.toString();
    final status = OrderDbStatus.domainFromDb(rawStatus);
    final chefId = r['chef_id'] as String?;
    final chefName = _resolveChefDisplayName(
      kitchenByChefId: kitchenByChefId,
      chefId: chefId,
      orderChefName: r['chef_name'] as String?,
    );
    final comm = r['commission_amount'];
    return OrderModel(
      id: id,
      customerId: r['customer_id']?.toString(),
      customerName: r['customer_name'] as String? ?? '',
      chefId: chefId,
      chefName: chefName,
      items: items,
      totalAmount: OrderSupabaseHydration.toDouble(r['total_amount']),
      commissionAmount:
          comm == null ? null : OrderSupabaseHydration.toDouble(comm),
      status: status,
      dbStatus: rawStatus,
      cancelReason: r['cancel_reason']?.toString(),
      createdAt: OrderSupabaseHydration.parseOrderDate(r['created_at']),
      deliveryAddress: r['delivery_address'] as String?,
      notes: OrderSupabaseHydration.resolveOrderNotesFromRow(status, r),
      idempotencyKey: r['idempotency_key'] as String?,
    );
  }

  Future<List<OrderModel>> _ordersWithItems(List<Map<String, dynamic>> rows) async {
    final chefIds = <String>{};
    final orderIds = <String>[];
    for (final r in rows) {
      final cid = r['chef_id']?.toString().trim();
      if (cid != null && cid.isNotEmpty) chefIds.add(cid);
      final oid = r['id']?.toString();
      if (oid != null && oid.isNotEmpty) orderIds.add(oid);
    }
    final kitchenByChefId = await _fetchKitchenNamesByChefIds(chefIds);
    final itemsByOrder =
        await OrderSupabaseHydration.fetchOrderItemsByOrderIds(_sb, orderIds);
    final orders = <OrderModel>[];
    for (final r in rows) {
      final oid = r['id']?.toString();
      if (oid == null || oid.isEmpty) continue;
      final o = _orderFromRowData(
        r,
        kitchenByChefId,
        itemsByOrder[oid] ?? const [],
      );
      if (o != null) orders.add(o);
    }
    return orders;
  }
}
