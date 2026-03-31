import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../../orders/data/datasources/orders_datasource_exceptions.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/data/models/order_model.dart';

/// Supabase orders + order_items for customer: create order, watch by customer, watch single, cancel.
/// Tables: orders (id, customer_id, chef_id, status, total_amount, commission_amount, notes,
///         delivery_address, customer_name, chef_name, created_at, updated_at)
///         order_items (id, order_id, menu_item_id or dish_id, quantity, unit_price)
class CustomerOrdersSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.client;

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

    const uuid = Uuid();
    final orderId = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    // Status must match DB enum: pending, accepted, preparing, ready, completed, cancelled,
    // paid_waiting_acceptance, cancelled_by_customer, cancelled_by_cook, cancelled_payment_failed, expired, rejected
    // Use 'pending' for new orders (safest value).
    const status = 'pending';
    if (kDebugMode) {
      debugPrint(
        '[CustomerOrdersSupabase] createOrder start customer=$customerId chef=$chefId items=${items.length}',
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
    final orderItems = items.map<Map<String, dynamic>>((e) {
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
      for (final item in items) {
        final dishId = (item['id'] as String?) ?? (item['dishId'] as String?);
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        if (dishId == null || dishId.isEmpty || qty <= 0) continue;

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
            await _increaseRemainingQuantity(dishId: d.dishId, quantity: d.quantity);
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

  /// Customer-only transitions via [transition_order_status] (cancel / expire while pending).
  Future<void> _customerTransitionOrderStatus(String orderId, String newStatus) async {
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
      },
    );
  }

  Future<void> cancelOrderByCustomer(String orderId) async {
    await _customerTransitionOrderStatus(orderId, 'cancelled_by_customer');
  }

  /// Timeout safeguard: move waiting orders to terminal expired state via backend.
  /// Stock restoration is expected to be handled server-side once.
  Future<void> expireOrderByTimeout(String orderId) async {
    await _customerTransitionOrderStatus(orderId, 'expired');
  }

  Future<OrderModel?> _orderFromRow(Map<String, dynamic> r) async {
    final id = r['id'] as String?;
    if (id == null) return null;
    final items = await _fetchOrderItems(id);
    final status = _orderStatusFromString(r['status'] as String?);
    return OrderModel(
      id: id,
      customerId: r['customer_id']?.toString(),
      customerName: r['customer_name'] as String? ?? '',
      chefId: r['chef_id'] as String?,
      chefName: r['chef_name'] as String?,
      items: items,
      totalAmount: _toDouble(r['total_amount']),
      status: status,
      createdAt: _parseDate(r['created_at']),
      deliveryAddress: r['delivery_address'] as String?,
      notes: (r['rejection_reason'] as String?)?.isNotEmpty == true
          ? r['rejection_reason'] as String?
          : r['notes'] as String?,
    );
  }

  Future<List<OrderModel>> _ordersWithItems(List<Map<String, dynamic>> rows) async {
    final orders = <OrderModel>[];
    for (final r in rows) {
      final o = await _orderFromRow(r);
      if (o != null) orders.add(o);
    }
    return orders;
  }

  Future<List<OrderItemEntity>> _fetchOrderItems(String orderId) async {
    final rows = await _sb.from('order_items').select().eq('order_id', orderId);
    return (rows as List).map((r) {
      final id = r['id'] as String? ?? '';
      return OrderItemModel(
        id: id,
        dishName: r['dish_name'] as String? ?? 'Item',
        quantity: (r['quantity'] as num?)?.toInt() ?? 1,
        price: _toDouble(r['unit_price'] ?? r['price']),
      );
    }).toList();
  }

  static OrderStatus _orderStatusFromString(String? v) {
    switch (v) {
      case 'pending':
      case 'paid_waiting_acceptance':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'rejected':
        return OrderStatus.rejected;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'cancelled_by_customer':
      case 'cancelled_by_cook':
      case 'cancelled_payment_failed':
      case 'expired':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static double _toDouble(dynamic x) {
    if (x == null) return 0;
    if (x is num) return x.toDouble();
    if (x is String) return double.tryParse(x) ?? 0;
    return 0;
  }

  static DateTime _parseDate(dynamic x) {
    if (x == null) return DateTime.now();
    if (x is DateTime) return x;
    if (x is String) return DateTime.tryParse(x) ?? DateTime.now();
    return DateTime.now();
  }
}
