import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/utils/local_calendar_day_utc_bounds.dart';
import '../../../customer/data/datasources/customer_orders_supabase_datasource.dart';
import '../../domain/chef_today_stats_aggregator.dart';
import '../../domain/entities/chef_today_stats.dart';
import '../../domain/entities/order_entity.dart';
import '../models/order_model.dart';
import '../order_db_status.dart';
import '../order_supabase_hydration.dart';
import 'orders_datasource_exceptions.dart';
import 'orders_remote_datasource.dart';

/// Supabase-backed orders for cook and customer sessions.
///
/// Scopes all access with [chefId] or [customerId]. No scope ⇒ read APIs return empty;
/// mutations throw [OrdersScopeException] or [ArgumentError].
///
/// **Status writes (production):** chef/customer mutations use only
/// [transition_order_status]. Direct `orders` PATCH after RPC failure runs in
/// [kDebugMode] only (local dev without RPC). Release/profile builds surface the RPC error.
///
/// [createOrder] delegates to [CustomerOrdersSupabaseDatasource] so stock/idempotency match
/// checkout; the canonical payment flow still calls that datasource directly.
class OrdersSupabaseDataSource implements OrdersRemoteDataSource {
  OrdersSupabaseDataSource({this.chefId, this.customerId});

  final String? chefId;
  final String? customerId;

  static SupabaseClient get _sb => SupabaseConfig.dataClient;

  static const _orderSelect =
      'id,customer_id,customer_name,chef_id,chef_name,status,total_amount,commission_amount,'
      'idempotency_key,created_at,updated_at,delivery_address,notes,rejection_reason,cancel_reason';

  static const _defaultListLimit = 150;
  static const _maxListLimit = 500;
  static const _defaultCompletedLimit = 500;
  static const _maxCompletedLimit = 1000;
  static const _maxRejectionReasonLength = 2000;
  static const _maxCreateOrderLineItems = 80;
  static const _maxLineItemQuantity = 999;

  static final Set<String> _loggedUnknownStatuses = {};

  bool get _hasChefScope => chefId != null && chefId!.isNotEmpty;
  bool get _hasCustomerScope => customerId != null && customerId!.isNotEmpty;
  bool get _hasReadScope => _hasChefScope || _hasCustomerScope;

  int _pageLimit(int? limit, {int defaultLimit = _defaultListLimit}) {
    final v = limit ?? defaultLimit;
    if (v < 1) return 1;
    if (v > _maxListLimit) return _maxListLimit;
    return v;
  }

  int _pageOffset(int? offset) {
    final o = offset ?? 0;
    return o < 0 ? 0 : o;
  }

  int _inclusiveRangeEnd(int offset, int limit) => offset + limit - 1;

  int _completedLimit(int? limit) {
    final v = limit ?? _defaultCompletedLimit;
    if (v < 1) return 1;
    if (v > _maxCompletedLimit) return _maxCompletedLimit;
    return v;
  }

  void _requireOrderId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Order id must not be empty');
    }
  }

  void _requireMutationScope() {
    if (!_hasChefScope) {
      throw OrdersScopeException('Cook scope required for this order action');
    }
  }

  bool _rowInScope(Map<String, dynamic> r) {
    if (_hasChefScope) {
      return (r['chef_id'] ?? '').toString() == chefId;
    }
    if (_hasCustomerScope) {
      return (r['customer_id'] ?? '').toString() == customerId;
    }
    return false;
  }

  Future<T> _guard<T>(String operation, Future<T> Function() body) async {
    try {
      return await body();
    } on ArgumentError catch (e, st) {
      Error.throwWithStackTrace(e, st);
    } on OrdersDataSourceException catch (e, st) {
      Error.throwWithStackTrace(e, st);
    } catch (e, st) {
      ordersDataSourceRethrowMapped(e, st, operation);
    }
  }

  String? _sanitizeRejectionReason(String? reason) {
    if (reason == null) return null;
    final t = reason.trim();
    if (t.isEmpty) return null;
    if (t.length <= _maxRejectionReasonLength) return t;
    return t.substring(0, _maxRejectionReasonLength);
  }

  void _validateCreateOrderInputs({
    required String customerId,
    required String customerName,
    required String chefId,
    required String chefName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) {
    if (customerId.trim().isEmpty || chefId.trim().isEmpty) {
      throw ArgumentError('customerId and chefId are required');
    }
    if (customerName.trim().isEmpty) {
      throw ArgumentError.value(
        customerName,
        'customerName',
        'customerName must not be empty',
      );
    }
    if (chefName.trim().isEmpty) {
      throw ArgumentError.value(
        chefName,
        'chefName',
        'chefName must not be empty',
      );
    }
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'At least one line item is required');
    }
    if (items.length > _maxCreateOrderLineItems) {
      throw ArgumentError.value(
        items,
        'items',
        'At most $_maxCreateOrderLineItems line items per order',
      );
    }
    if (totalAmount.isNaN || totalAmount.isInfinite || totalAmount < 0) {
      throw ArgumentError.value(totalAmount, 'totalAmount', 'Invalid total');
    }
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      final q = m['quantity'];
      final n = q is num ? q.toInt() : int.tryParse('$q') ?? 0;
      if (n < 1) {
        throw ArgumentError.value(
          items,
          'items',
          'Line item $i: quantity must be >= 1',
        );
      }
      if (n > _maxLineItemQuantity) {
        throw ArgumentError.value(
          items,
          'items',
          'Line item $i: quantity must be <= $_maxLineItemQuantity',
        );
      }
    }
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
    return _guard('createOrder', () async {
      _validateCreateOrderInputs(
        customerId: customerId,
        customerName: customerName,
        chefId: chefId,
        chefName: chefName,
        items: items,
        totalAmount: totalAmount,
      );
      final key = (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
          ? idempotencyKey.trim()
          : const Uuid().v4();
      final ds = CustomerOrdersSupabaseDatasource();
      return ds.createOrder(
        customerId: customerId,
        customerName: customerName.trim(),
        chefId: chefId.trim(),
        chefName: chefName.trim(),
        idempotencyKey: key,
        items: items,
        totalAmount: totalAmount,
        commissionAmount: commissionAmount,
        deliveryAddress: deliveryAddress,
        notes: notes,
      );
    });
  }

  @override
  Future<List<OrderModel>> getOrders({int? limit, int? offset}) async {
    if (!_hasReadScope) return [];
    return _guard('getOrders', () async {
      final lim = _pageLimit(limit);
      final off = _pageOffset(offset);
      final end = _inclusiveRangeEnd(off, lim);
      final List<dynamic> raw;
      if (_hasChefScope) {
        raw = await _sb
            .from('orders')
            .select(_orderSelect)
            .eq('chef_id', chefId!)
            .order('created_at', ascending: false)
            .range(off, end);
      } else {
        raw = await _sb
            .from('orders')
            .select(_orderSelect)
            .eq('customer_id', customerId!)
            .order('created_at', ascending: false)
            .range(off, end);
      }
      final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return _hydrateOrderRows(rows);
    });
  }

  @override
  Future<List<OrderModel>> getOrdersByStatus(
    OrderStatus status, {
    int? limit,
    int? offset,
  }) async {
    if (!_hasReadScope) return [];
    return _guard('getOrdersByStatus', () async {
      final dbStatuses = OrderDbStatus.filterValuesFor(status);
      final lim = _pageLimit(limit);
      final off = _pageOffset(offset);
      final end = _inclusiveRangeEnd(off, lim);
      final List<dynamic> raw;
      if (_hasChefScope) {
        raw = await _sb
            .from('orders')
            .select(_orderSelect)
            .eq('chef_id', chefId!)
            .inFilter('status', dbStatuses)
            .order('created_at', ascending: false)
            .range(off, end);
      } else {
        raw = await _sb
            .from('orders')
            .select(_orderSelect)
            .eq('customer_id', customerId!)
            .inFilter('status', dbStatuses)
            .order('created_at', ascending: false)
            .range(off, end);
      }
      final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return _hydrateOrderRows(rows);
    });
  }

  @override
  Future<OrderModel> getOrderById(String id) async {
    _requireOrderId(id);
    if (!_hasReadScope) {
      throw OrdersScopeException(
        'No order scope (chef or customer session required)',
      );
    }
    return _guard('getOrderById', () async {
      final row =
          await _sb.from('orders').select(_orderSelect).eq('id', id).maybeSingle();
      if (row == null) {
        throw OrderNotFoundException();
      }
      final m = Map<String, dynamic>.from(row);
      if (!_rowInScope(m)) {
        throw OrderNotFoundException();
      }
      final hydrated = await _hydrateOrderRows([m]);
      if (hydrated.isEmpty) {
        throw OrderNotFoundException();
      }
      return hydrated.first;
    });
  }

  @override
  Future<void> acceptOrder(String id) async {
    _requireOrderId(id);
    _requireMutationScope();
    return _guard('acceptOrder', () async {
      final snap = await _sb
          .from('orders')
          .select('status,chef_id')
          .eq('id', id)
          .maybeSingle();
      if (snap == null) throw OrderNotFoundException();
      final row = Map<String, dynamic>.from(snap);
      if ((row['chef_id'] ?? '').toString() != chefId) {
        throw OrderNotFoundException();
      }
      final rawStatus = row['status']?.toString();
      if (!OrderDbStatus.canChefAcceptDbStatus(rawStatus)) {
        throw OrdersDataSourceException(
          'Only orders waiting for acceptance can be accepted (current: ${row['status']}).',
        );
      }
      await _transitionOrderStatus(id: id, newStatus: 'accepted');
    });
  }

  @override
  Future<void> rejectOrder(String id, {String? reason}) async {
    _requireOrderId(id);
    _requireMutationScope();
    return _guard('rejectOrder', () async {
      final snap = await _sb
          .from('orders')
          .select('status,chef_id')
          .eq('id', id)
          .maybeSingle();
      if (snap == null) throw OrderNotFoundException();
      final row = Map<String, dynamic>.from(snap);
      if ((row['chef_id'] ?? '').toString() != chefId) {
        throw OrderNotFoundException();
      }
      final rawReject = row['status']?.toString();
      if (!OrderDbStatus.canChefRejectDbStatus(rawReject)) {
        throw OrdersDataSourceException(
          'This order cannot be rejected in its current state.',
        );
      }
      final cleanReason = _sanitizeRejectionReason(reason);
      // Cook UI uses reject as a timeout path for unanswered "new" orders.
      // Map that to unified `cancelled` + system_cancelled_frozen (same customer-facing label as other system cancels).
      if (cleanReason != null && cleanReason == 'Time expired') {
        await _transitionOrderStatus(
          id: id,
          newStatus: 'cancelled',
          cancelReason: OrderDbStatus.internalSystemCancelledFrozen,
        );
        return;
      }
      await _rejectOrderAtomic(id, cleanReason);
    });
  }

  @override
  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    _requireOrderId(id);
    _requireMutationScope();
    return _guard('updateOrderStatus', () async {
      final snap = await _sb
          .from('orders')
          .select('status,chef_id')
          .eq('id', id)
          .maybeSingle();
      if (snap == null) throw OrderNotFoundException();
      final row = Map<String, dynamic>.from(snap);
      if ((row['chef_id'] ?? '').toString() != chefId) {
        throw OrderNotFoundException();
      }
      final rawAdvance = row['status']?.toString();
      if (!OrderDbStatus.canChefAdvanceDbStatus(rawAdvance, status)) {
        throw OrdersDataSourceException(
          'Invalid kitchen step (current: ${row['status']}); use Accept, then advance preparing → ready → completed in order.',
        );
      }
      await _transitionOrderStatus(
        id: id,
        newStatus: OrderDbStatus.mutationValueFor(status),
      );
    });
  }

  /// Reject uses [transition_order_status] (stores optional cook note via [p_rejection_reason] on server).
  Future<void> _rejectOrderAtomic(String id, String? cleanReason) async {
    await _transitionOrderStatus(
      id: id,
      newStatus: 'cancelled',
      cancelReason: OrderDbStatus.internalCookRejected,
      pRejectionReason: cleanReason,
    );
  }

  Future<void> _transitionOrderStatus({
    required String id,
    required String newStatus,
    String? cancelReason,
    bool customerSystemCancel = false,
    String? pRejectionReason,
  }) async {
    _requireOrderId(id);
    final current = await _sb
        .from('orders')
        .select('updated_at,chef_id')
        .eq('id', id)
        .maybeSingle();
    if (current == null) {
      throw OrderNotFoundException();
    }
    final rowMap = Map<String, dynamic>.from(current);
    if (_hasChefScope && (rowMap['chef_id'] ?? '').toString() != chefId) {
      throw OrderNotFoundException();
    }
    final expectedUpdatedAt = rowMap['updated_at']?.toString();
    try {
      await _sb.rpc<dynamic>(
        'transition_order_status',
        params: {
          'order_id': id,
          'new_status': newStatus,
          'expected_updated_at': expectedUpdatedAt,
          if (cancelReason != null) 'cancel_reason': cancelReason,
          'customer_system_cancel': customerSystemCancel,
          if (pRejectionReason != null && pRejectionReason.trim().isNotEmpty)
            'p_rejection_reason': pRejectionReason.trim(),
        },
      );
      return;
    } on PostgrestException catch (e, st) {
      final code = (e.code ?? '').trim();
      final msg = e.message.toLowerCase();
      if (code == '42501' ||
          code == '401' ||
          code == '403' ||
          msg.contains('permission denied') ||
          msg.contains('jwt') ||
          msg.contains('row-level security')) {
        ordersDataSourceRethrowMapped(e, st, 'transitionOrderStatus');
      }
      if (!kDebugMode) {
        ordersDataSourceRethrowMapped(e, st, 'transition_order_status');
      }
      debugPrint(
        '[OrdersSupabase] transition_order_status RPC failed (debug fallback only): ${e.message}\n$st',
      );
    } catch (e, st) {
      if (!kDebugMode) {
        ordersDataSourceRethrowMapped(e, st, 'transition_order_status');
      }
      debugPrint(
        '[OrdersSupabase] transition_order_status RPC failed: $e\n$st',
      );
    }

    final patch = <String, dynamic>{
      'status': newStatus,
      if (cancelReason != null) 'cancel_reason': cancelReason,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    var q = _sb.from('orders').update(patch).eq('id', id);
    if (_hasChefScope) {
      q = q.eq('chef_id', chefId!);
    }
    if (expectedUpdatedAt != null && expectedUpdatedAt.isNotEmpty) {
      q = q.eq('updated_at', expectedUpdatedAt);
    }
    final updated = await q.select('id').maybeSingle();
    if (updated == null) {
      throw OrderConcurrencyException();
    }
  }

  Future<List<OrderModel>> _hydrateWatchSnapshot(dynamic raw) async {
    try {
      final rows = _normalizeStreamRows(raw);
      final scoped = rows.where(_rowInScope).toList();
      return _hydrateOrderRows(scoped);
    } catch (e, st) {
      debugPrint('[OrdersSupabase][watchOrders][asyncMap] $e\n$st');
      if (e is OrdersDataSourceException) {
        Error.throwWithStackTrace(e, st);
      }
      ordersDataSourceRethrowMapped(e, st, 'watchOrders');
    }
  }

  @override
  Stream<List<OrderModel>> watchOrders({List<OrderStatus>? statuses}) {
    if (!_hasReadScope) {
      return Stream<List<OrderModel>>.value(const []);
    }

    final allowedEnums =
        statuses != null && statuses.isNotEmpty ? statuses.toSet() : null;

    final Stream<List<OrderModel>> hydrated = _hasChefScope
        ? _sb
            .from('orders')
            .stream(primaryKey: const ['id'])
            .eq('chef_id', chefId!)
            .order('created_at')
            .asyncMap(_hydrateWatchSnapshot)
        : _sb
            .from('orders')
            .stream(primaryKey: const ['id'])
            .eq('customer_id', customerId!)
            .order('created_at')
            .asyncMap(_hydrateWatchSnapshot);

    Stream<List<OrderModel>> filtered = hydrated;
    if (allowedEnums != null) {
      filtered = hydrated.map((List<OrderModel> list) {
        return list.where((OrderModel o) => allowedEnums.contains(o.status)).toList();
      });
    }

    return filtered.handleError((Object e, StackTrace st) {
      debugPrint('[OrdersSupabase][watchOrders] $e\n$st');
      if (e is OrdersDataSourceException) {
        Error.throwWithStackTrace(e, st);
      }
      ordersDataSourceRethrowMapped(e, st, 'watchOrders');
    });
  }

  static List<Map<String, dynamic>> _normalizeStreamRows(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Batch-load items for many orders (avoids N+1 queries on list endpoints).
  Future<List<OrderModel>> _hydrateOrderRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = <String>[];
    for (final r in rows) {
      final oid = r['id']?.toString();
      if (oid != null && oid.isNotEmpty) ids.add(oid);
    }
    if (ids.isEmpty) return [];

    String? profileKitchenName;
    if (_hasChefScope && chefId != null && chefId!.isNotEmpty) {
      try {
        final pr = await _sb
            .from('chef_profiles')
            .select('kitchen_name')
            .eq('id', chefId!)
            .maybeSingle();
        final raw = pr?['kitchen_name']?.toString().trim();
        if (raw != null && raw.isNotEmpty) profileKitchenName = raw;
      } catch (e, st) {
        debugPrint('[OrdersSupabase] kitchen_name fetch: $e\n$st');
      }
    }

    final itemsByOrder =
        await OrderSupabaseHydration.fetchOrderItemsByOrderIds(_sb, ids);
    final out = <OrderModel>[];
    for (final r in rows) {
      final oid = r['id']?.toString();
      if (oid == null || oid.isEmpty) continue;
      final merged = Map<String, dynamic>.from(r);
      if (profileKitchenName != null) {
        merged['chef_name'] = profileKitchenName;
      }
      final o = _orderModelFromRow(merged, itemsByOrder[oid] ?? const []);
      if (o != null) out.add(o);
    }
    return out;
  }

  OrderModel? _orderModelFromRow(Map<String, dynamic> r, List<OrderItemEntity> items) {
    final id = r['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final rawStatus = r['status']?.toString();
    if (kDebugMode &&
        rawStatus != null &&
        rawStatus.isNotEmpty &&
        !OrderDbStatus.recognizes(rawStatus)) {
      if (!_loggedUnknownStatuses.contains(rawStatus)) {
        _loggedUnknownStatuses.add(rawStatus);
        debugPrint(
          '[OrdersSupabase] Unknown order status "$rawStatus"; mapping to pending',
        );
      }
    }
    final status = OrderDbStatus.domainFromDb(rawStatus);
    final comm = r['commission_amount'];
    return OrderModel(
      id: id,
      customerId: r['customer_id']?.toString(),
      customerName: r['customer_name'] as String? ?? '',
      chefId: r['chef_id']?.toString(),
      chefName: r['chef_name'] as String?,
      items: items,
      totalAmount: _toDouble(r['total_amount']),
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

  static double _toDouble(dynamic x) {
    if (x == null) return 0;
    if (x is num) return x.toDouble();
    if (x is String) return double.tryParse(x) ?? 0;
    return 0;
  }

  /// Local calendar day on the device → UTC bounds; filters `orders.created_at`.
  @override
  Future<ChefTodayStats> getTodayStats() async {
    if (!_hasChefScope) {
      return const ChefTodayStats(
        completedRevenueToday: 0,
        completedOrdersToday: 0,
        inKitchenCountToday: 0,
        pipelineOrderValueToday: 0,
      );
    }
    return _guard('getTodayStats', () async {
      final bounds = LocalCalendarDayUtcBounds.forNow();
      final rows = await _sb
          .from('orders')
          .select('total_amount,status,created_at,chef_id')
          .eq('chef_id', chefId!)
          .gte('created_at', bounds.startUtc.toIso8601String())
          .lt('created_at', bounds.endUtc.toIso8601String());
      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return aggregateChefTodayStatsFromOrderRows(list);
    });
  }

  @override
  Future<List<OrderModel>> getDelayedOrders(Duration threshold) async {
    if (!_hasChefScope) return [];
    if (threshold.isNegative) {
      throw ArgumentError.value(threshold, 'threshold', 'Invalid duration');
    }
    if (threshold.inMicroseconds == 0) {
      return [];
    }
    return _guard('getDelayedOrders', () async {
      final cutoff = DateTime.now().toUtc().subtract(threshold);
      final raw = await _sb
          .from('orders')
          .select(_orderSelect)
          .eq('chef_id', chefId!)
          .inFilter('status', OrderDbStatus.delayedAttentionStatuses)
          .lt('created_at', cutoff.toIso8601String())
          .order('created_at', ascending: true)
          .limit(100);
      final rows =
          (raw as List<dynamic>? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return _hydrateOrderRows(rows);
    });
  }

  @override
  Future<List<OrderModel>> getCompletedOrdersSince(
    DateTime since, {
    int? limit,
  }) async {
    if (!_hasChefScope) return [];
    return _guard('getCompletedOrdersSince', () async {
      final lim = _completedLimit(limit);
      final rows = await _sb
          .from('orders')
          .select(_orderSelect)
          .eq('chef_id', chefId!)
          .eq('status', 'completed')
          .gte('created_at', since.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(lim);
      final list = (rows as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return _hydrateOrderRows(list);
    });
  }
}

/// Legacy name kept for imports and docs.
typedef OrdersFirebaseDataSource = OrdersSupabaseDataSource;
