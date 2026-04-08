import 'dart:math' show min;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/order_entity.dart';
import 'models/order_model.dart';

/// Shared Supabase row parsing for orders (customer + cook datasources).
abstract final class OrderSupabaseHydration {
  OrderSupabaseHydration._();

  static final DateTime invalidDateUtc =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Same sentinel as [OrdersSupabaseDataSource] for missing/invalid `created_at`.
  static DateTime parseOrderDate(dynamic x) {
    if (x == null) return invalidDateUtc;
    if (x is DateTime) return x.toUtc();
    if (x is String) {
      final d = DateTime.tryParse(x);
      return d != null ? d.toUtc() : invalidDateUtc;
    }
    return invalidDateUtc;
  }

  /// Align customer/cook UIs: rejection text only merges into [notes] for terminal cancel/reject.
  static String? resolveOrderNotesFromRow(
    OrderStatus status,
    Map<String, dynamic> r,
  ) {
    if (status == OrderStatus.cancelled || status == OrderStatus.rejected) {
      return (r['rejection_reason'] ?? r['notes']) as String?;
    }
    return r['notes'] as String?;
  }

  static const maxIdsPerInQuery = 50;

  static double toDouble(dynamic x) {
    if (x == null) return 0;
    if (x is num) return x.toDouble();
    if (x is String) return double.tryParse(x) ?? 0;
    return 0;
  }

  /// Batch-load [order_items] for many orders and enrich empty `dish_name` from [menu_items].
  static Future<Map<String, List<OrderItemEntity>>> fetchOrderItemsByOrderIds(
    SupabaseClient sb,
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return {};
    final list = <dynamic>[];
    for (var i = 0; i < orderIds.length; i += maxIdsPerInQuery) {
      final slice = orderIds.sublist(i, min(i + maxIdsPerInQuery, orderIds.length));
      final chunk = await sb
          .from('order_items')
          .select('id,order_id,dish_name,quantity,unit_price,price,menu_item_id')
          .inFilter('order_id', slice);
      list.addAll(chunk as List<dynamic>);
    }
    final menuIds = <String>[];
    for (final r in list) {
      final row = r as Map<String, dynamic>;
      final menuId = row['menu_item_id']?.toString();
      if (menuId != null && menuId.isNotEmpty) menuIds.add(menuId);
    }

    final menuNameById = <String, String>{};
    if (menuIds.isNotEmpty) {
      try {
        final uniqueMenuIds = menuIds.toSet().toList();
        final menuRowsAccum = <dynamic>[];
        for (var i = 0; i < uniqueMenuIds.length; i += maxIdsPerInQuery) {
          final slice = uniqueMenuIds.sublist(
            i,
            min(i + maxIdsPerInQuery, uniqueMenuIds.length),
          );
          final part =
              await sb.from('menu_items').select('id,name').inFilter('id', slice);
          menuRowsAccum.addAll(part as List<dynamic>);
        }
        for (final r in menuRowsAccum) {
          if (r is! Map) continue;
          final m = Map<String, dynamic>.from(r);
          final kid = m['id']?.toString() ?? '';
          final nm = m['name']?.toString() ?? '';
          if (kid.isNotEmpty && nm.isNotEmpty) menuNameById[kid] = nm;
        }
      } catch (_) {
        // Names optional; fall back to dish_name / 'Item'.
      }
    }

    final byOrder = <String, List<OrderItemEntity>>{};
    for (final r in list) {
      final row = r as Map<String, dynamic>;
      final oid = row['order_id']?.toString() ?? '';
      if (oid.isEmpty) continue;
      final fallbackId = row['menu_item_id']?.toString() ?? '';
      final name = (row['dish_name'] as String?)?.trim();
      final resolvedName = (name != null && name.isNotEmpty)
          ? name
          : (menuNameById[fallbackId] ?? 'Item');
      final item = OrderItemModel(
        id: row['id']?.toString() ?? '',
        dishName: resolvedName,
        quantity: (row['quantity'] as num?)?.toInt() ?? 1,
        price: toDouble(row['unit_price'] ?? row['price']),
      );
      byOrder.putIfAbsent(oid, () => []).add(item);
    }
    for (final id in orderIds) {
      byOrder.putIfAbsent(id, () => []);
    }
    return byOrder;
  }
}
