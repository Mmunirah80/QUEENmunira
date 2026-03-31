import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../models/admin_dashboard_stats.dart';

class AdminSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.client;

  Future<AdminDashboardStats> getDashboardStats() async {
    final result = await _sb.rpc<dynamic>('get_admin_dashboard_stats');
    if (result is Map<String, dynamic>) {
      return AdminDashboardStats.fromMap(result);
    }
    if (result is List && result.isNotEmpty && result.first is Map<String, dynamic>) {
      return AdminDashboardStats.fromMap(result.first as Map<String, dynamic>);
    }
    throw Exception('Invalid dashboard response');
  }

  /// Chef-uploaded verification files awaiting review ([chef_documents.status] = pending).
  /// Adds [_kitchen_name] from [chef_profiles] for admin UI (falls back to short chef id).
  /// [offset] is 0-based; uses inclusive PostgREST range [offset, offset + limit - 1].
  Future<List<Map<String, dynamic>>> fetchPendingChefDocuments({
    int limit = 25,
    int offset = 0,
  }) async {
    if (limit <= 0) return const [];
    final from = offset;
    final to = offset + limit - 1;
    final rows = await _sb
        .from('chef_documents')
        .select(
          'id,chef_id,document_type,status,file_url,expiry_date,rejection_reason,updated_at,created_at',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .range(from, to);
    final list = (rows as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final chefIds = list
        .map((r) => (r['chef_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (chefIds.isEmpty) return list;

    final profRows = await _sb
        .from('chef_profiles')
        .select('id,kitchen_name')
        .inFilter('id', chefIds);
    final kitchenByChef = <String, String>{};
    for (final raw in profRows as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final kn = (m['kitchen_name'] ?? '').toString().trim();
      kitchenByChef[id] = kn.isNotEmpty ? kn : id;
    }
    for (final r in list) {
      final cid = (r['chef_id'] ?? '').toString();
      r['_kitchen_name'] = kitchenByChef[cid] ?? cid;
    }
    return list;
  }

  /// Approve or reject a document row (same DB pipeline as cook simulation): [apply_chef_document_review].
  Future<void> setChefDocumentStatus({
    required String documentId,
    required String status,
    String? rejectionReason,
  }) async {
    await _sb.rpc<void>(
      'apply_chef_document_review',
      params: {
        'p_document_id': documentId,
        'p_status': status,
        'p_rejection_reason': rejectionReason,
      },
    );
  }

  Future<void> logAction({
    required String action,
    String? targetTable,
    String? targetId,
    Map<String, dynamic>? payload,
  }) async {
    await _sb.rpc<dynamic>(
      'log_admin_action',
      params: {
        'p_action': action,
        'p_target_table': targetTable,
        'p_target_id': targetId,
        'p_payload': payload ?? <String, dynamic>{},
      },
    );
  }

  /// [conversations] row for this order (per-order threads), if [order_id] column exists.
  Future<String?> fetchCustomerChefConversationIdForOrder(String orderId) async {
    final id = orderId.trim();
    if (id.isEmpty) return null;
    try {
      final row = await _sb
          .from('conversations')
          .select('id')
          .eq('order_id', id)
          .eq('type', 'customer-chef')
          .maybeSingle();
      if (row == null) return null;
      final cid = (row['id'] ?? '').toString().trim();
      return cid.isEmpty ? null : cid;
    } catch (e, st) {
      debugPrint('[Admin] fetchCustomerChefConversationIdForOrder: $e\n$st');
      return null;
    }
  }

  /// Reels moderation: newest first, with [_kitchen_name] from chef_profiles.
  /// Recent orders across all customers/chefs (RLS: admin SELECT on [orders]).
  Future<List<Map<String, dynamic>>> fetchRecentOrdersForAdmin({
    int limit = 150,
    int offset = 0,
  }) async {
    if (limit <= 0) return const [];
    final from = offset;
    final to = offset + limit - 1;
    final rows = await _sb
        .from('orders')
        .select(
          'id,customer_id,customer_name,chef_id,chef_name,status,total_amount,created_at,updated_at,delivery_address,notes',
        )
        .order('created_at', ascending: false)
        .range(from, to);
    return (rows as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Single order + line items for admin monitoring (read-only).
  Future<Map<String, dynamic>?> fetchOrderDetailForAdmin(String orderId) async {
    if (orderId.trim().isEmpty) return null;
    final row = await _sb
        .from('orders')
        .select(
          'id,customer_id,customer_name,chef_id,chef_name,status,total_amount,created_at,updated_at,delivery_address,notes,rejection_reason',
        )
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) return null;
    final order = Map<String, dynamic>.from(row);
    final itemsRaw = await _sb
        .from('order_items')
        .select('id,dish_name,quantity,unit_price,price,menu_item_id')
        .eq('order_id', orderId);
    final items = (itemsRaw as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return {'order': order, 'items': items};
  }

  /// Recent [profiles] rows for admin directory (RLS: admin SELECT all).
  Future<List<Map<String, dynamic>>> fetchProfilesForAdmin({
    int limit = 200,
    int offset = 0,
  }) async {
    if (limit <= 0) return const [];
    final from = offset;
    final to = offset + limit - 1;
    final rows = await _sb
        .from('profiles')
        .select('id, role, full_name, phone, is_blocked')
        .order('full_name', ascending: true)
        .range(from, to);
    return (rows as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllReelsForAdmin({int limit = 100}) async {
    if (limit <= 0) return const [];
    final rows = await _sb
        .from('reels')
        .select('id,chef_id,video_url,thumbnail_url,caption,dish_id,created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (rows as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    final chefIds = list
        .map((r) => (r['chef_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (chefIds.isEmpty) return list;
    final prof = await _sb.from('chef_profiles').select('id,kitchen_name').inFilter('id', chefIds);
    final names = <String, String>{};
    for (final raw in prof as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final kn = (m['kitchen_name'] ?? '').toString().trim();
      names[id] = kn.isNotEmpty ? kn : id;
    }
    for (final r in list) {
      final cid = (r['chef_id'] ?? '').toString();
      r['_kitchen_name'] = names[cid] ?? cid;
    }
    return list;
  }
}
