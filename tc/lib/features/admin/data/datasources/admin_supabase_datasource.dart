import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/inspection_outcome.dart';

String _adminSanitizeIlike(String q) =>
    q.trim().replaceAll(RegExp(r'[%_]'), '');

bool _adminIsFullOrderUuid(String q) {
  final t = q.trim().toLowerCase();
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(t);
}

class AdminSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.client;

  /// Cached after first probe: [profiles.email] may not exist in all schemas.
  String? _profilesSelectColumns;

  Future<String> _resolveProfilesSelect() async {
    if (_profilesSelectColumns != null) return _profilesSelectColumns!;
    const candidates = <String>[
      'id, role, full_name, phone, is_blocked, email, created_at',
      'id, role, full_name, phone, is_blocked, created_at',
      'id, role, full_name, phone, is_blocked, email',
      'id, role, full_name, phone, is_blocked',
    ];
    for (final sel in candidates) {
      try {
        await _sb.from('profiles').select(sel).limit(1);
        _profilesSelectColumns = sel;
        return sel;
      } catch (e, st) {
        debugPrint('[Admin] profiles select probe "$sel": $e\n$st');
      }
    }
    _profilesSelectColumns = 'id, role, full_name, phone, is_blocked';
    return _profilesSelectColumns!;
  }

  /// Online, not suspended, not blocked ([profiles.is_blocked]), not currently frozen ([freeze_until] in the future).
  Future<List<Map<String, dynamic>>> fetchOnlineChefsForInspection() async {
    final rows = await _sb
        .from('chef_profiles')
        .select('id,kitchen_name,is_online,warning_count,freeze_until,suspended,vacation_mode')
        .eq('is_online', true)
        .eq('suspended', false)
        .order('kitchen_name', ascending: true);
    final list = (rows as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (list.isEmpty) return list;

    final ids = list
        .map((e) => (e['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final blocked = <String, bool>{};
    try {
      final pr = await _sb.from('profiles').select('id,is_blocked').inFilter('id', ids);
      for (final raw in pr as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) continue;
        blocked[id] = m['is_blocked'] == true;
      }
    } catch (e, st) {
      debugPrint('[Admin] fetchOnlineChefsForInspection profiles is_blocked: $e\n$st');
    }

    final now = DateTime.now();
    return list.where((r) {
      final id = (r['id'] ?? '').toString();
      if (blocked[id] == true) return false;
      if (r['vacation_mode'] == true) return false;
      final fuRaw = r['freeze_until'];
      if (fuRaw == null) return true;
      DateTime? fu;
      if (fuRaw is DateTime) {
        fu = fuRaw;
      } else if (fuRaw is String) {
        fu = DateTime.tryParse(fuRaw);
      }
      if (fu == null) return true;
      return !fu.isAfter(now);
    }).toList();
  }

  Future<Map<String, dynamic>> startInspectionCall(String chefId) async {
    final result = await _sb.rpc<dynamic>(
      'start_inspection_call',
      params: {'p_chef_id': chefId},
    );
    if (result is Map<String, dynamic>) return result;
    if (result is List && result.isNotEmpty && result.first is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw Exception('Invalid start_inspection_call response');
  }

  /// Server picks one eligible chef (random). Throws if none (e.g. `no eligible chefs`).
  Future<Map<String, dynamic>> startRandomInspectionCall() async {
    final result = await _sb.rpc<dynamic>('start_random_inspection_call');
    if (result is Map<String, dynamic>) return result;
    if (result is List && result.isNotEmpty && result.first is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw Exception('Invalid start_random_inspection_call response');
  }

  /// Live inspection: **outcome only** — [InspectionOutcome]. Penalties (warning / freeze length) are computed in
  /// `finalize_inspection_outcome` on the server; do not pass freeze duration or ladder step from the client.
  Future<Map<String, dynamic>> finalizeInspectionOutcome({
    required String callId,
    required InspectionOutcome outcome,
    String? note,
  }) async {
    final result = await _sb.rpc<dynamic>(
      'finalize_inspection_outcome',
      params: {
        'p_call_id': callId,
        'p_outcome': outcome.serverValue,
        'p_note': note,
      },
    );
    if (result is Map<String, dynamic>) return result;
    if (result is List && result.isNotEmpty && result.first is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return const <String, dynamic>{};
  }

  Future<void> cancelInspectionCall(String callId) async {
    await _sb.rpc<void>(
      'cancel_inspection_call',
      params: {'p_call_id': callId},
    );
  }

  /// Snapshot for inspection call UI (escalation preview).
  Future<Map<String, dynamic>?> fetchChefInspectionSnapshot(String chefId) async {
    if (chefId.isEmpty) return null;
    try {
      final row = await _sb
          .from('chef_profiles')
          .select('kitchen_name,warning_count,inspection_violation_count,inspection_penalty_step,freeze_until')
          .eq('id', chefId)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row as Map);
    } catch (e, st) {
      debugPrint('[Admin] fetchChefInspectionSnapshot (full): $e\n$st');
      try {
        final row = await _sb
            .from('chef_profiles')
            .select('kitchen_name,warning_count,freeze_until')
            .eq('id', chefId)
            .maybeSingle();
        if (row == null) return null;
        final m = Map<String, dynamic>.from(row as Map);
        m['inspection_violation_count'] = 0;
        m['inspection_penalty_step'] = 0;
        return m;
      } catch (e2, st2) {
        debugPrint('[Admin] fetchChefInspectionSnapshot (fallback): $e2\n$st2');
        return null;
      }
    }
  }

  /// [chef_violations] rows (admin RLS). Optional kitchen names from [chef_profiles].
  Future<List<Map<String, dynamic>>> fetchInspectionViolationsForAdmin({int limit = 200}) async {
    if (limit <= 0) return const [];
    try {
      final rows = await _sb
          .from('chef_violations')
          .select('id,chef_id,inspection_call_id,violation_index,reason,action_applied,note,created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (rows as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final chefIds = list
          .map((r) => (r['chef_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (chefIds.isEmpty) return list;
      final cp = await _sb.from('chef_profiles').select('id,kitchen_name').inFilter('id', chefIds);
      final names = <String, String>{};
      for (final raw in cp as List) {
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
    } catch (e, st) {
      debugPrint('[Admin] fetchInspectionViolationsForAdmin: $e\n$st');
      return const [];
    }
  }

  /// Recent inspection sessions (admin dashboard / history).
  Future<List<Map<String, dynamic>>> fetchInspectionCallsForAdmin({int limit = 40}) async {
    if (limit <= 0) return const [];
    final rows = await _sb
        .from('inspection_calls')
        .select(
          'id,chef_id,admin_id,channel_name,status,outcome,counted_as_violation,result_action,violation_reason,result_note,created_at,finalized_at,started_at,ended_at,selection_context',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Stream<Map<String, dynamic>?> watchInspectionCall(String callId) {
    if (callId.isEmpty) return const Stream<Map<String, dynamic>?>.empty();
    return _sb.from('inspection_calls').stream(primaryKey: ['id']).eq('id', callId).map((rows) {
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    });
  }

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

  /// Chef-uploaded verification files awaiting review ([chef_documents.status] = pending_review).
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
          'id,chef_id,document_type,status,file_url,expiry_date,no_expiry,rejection_reason,updated_at,created_at,reviewed_at',
        )
        .eq('status', 'pending_review')
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

  /// Kitchen display names for a set of chef profile ids (falls back to id).
  Future<Map<String, String>> fetchKitchenNamesForChefIds(List<String> chefIds) async {
    if (chefIds.isEmpty) return {};
    final profRows = await _sb.from('chef_profiles').select('id,kitchen_name').inFilter('id', chefIds);
    final kitchenByChef = <String, String>{};
    for (final raw in profRows as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final kn = (m['kitchen_name'] ?? '').toString().trim();
      kitchenByChef[id] = kn.isNotEmpty ? kn : id;
    }
    return kitchenByChef;
  }

  /// [profiles.full_name] for cook ids (admin directory labels).
  Future<Map<String, String>> fetchChefApplicantDisplayNames(List<String> chefIds) async {
    if (chefIds.isEmpty) return {};
    try {
      final rows = await _sb.from('profiles').select('id,full_name').inFilter('id', chefIds);
      final out = <String, String>{};
      for (final raw in rows as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final n = (m['full_name'] ?? '').toString().trim();
        out[id] = n.isNotEmpty ? n : id;
      }
      return out;
    } catch (e, st) {
      debugPrint('[Admin] fetchChefApplicantDisplayNames: $e\n$st');
      return {for (final id in chefIds) id: id};
    }
  }

  /// Distinct [chef_id] values that have at least one [chef_documents] row in `pending_review`,
  /// ordered by first-seen while scanning pending rows newest-first (approximates "recent activity").
  Future<({List<String> chefIds, bool hasMore})> fetchChefIdsWithPendingReviewDocuments({
    int limit = 12,
    int offset = 0,
  }) async {
    if (limit <= 0) return (chefIds: const <String>[], hasMore: false);
    const batchSize = 100;
    const maxScanRows = 5000;
    final ordered = <String>[];
    final seen = <String>{};
    var rowOffset = 0;
    while (ordered.length < offset + limit && rowOffset < maxScanRows) {
      final rows = await _sb
          .from('chef_documents')
          .select('chef_id')
          .eq('status', 'pending_review')
          .order('created_at', ascending: false)
          .range(rowOffset, rowOffset + batchSize - 1);
      final list = rows as List<dynamic>? ?? const <dynamic>[];
      if (list.isEmpty) break;
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m['chef_id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        ordered.add(id);
      }
      rowOffset += batchSize;
      if (list.length < batchSize) break;
    }
    final slice = ordered.skip(offset).take(limit).toList();
    final hasMore = ordered.length > offset + limit;
    return (chefIds: slice, hasMore: hasMore);
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

  /// Reels moderation: newest first, with [_kitchen_name] from chef_profiles.
  /// Recent orders across all customers/chefs (RLS: admin SELECT on [orders]).
  /// [searchQuery]: matches [customer_name], [chef_name], full order [id], or partial id via `id::text` ilike.
  /// When [searchQuery] is set, [chefIdEq] / [customerIdEq] / date bounds are applied in memory on the search result.
  Future<List<Map<String, dynamic>>> fetchRecentOrdersForAdmin({
    int limit = 150,
    int offset = 0,
    String? searchQuery,
    String? chefIdEq,
    String? customerIdEq,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) async {
    if (limit <= 0) return const [];
    final from = offset;
    final to = offset + limit - 1;
    final sel =
        'id,customer_id,customer_name,chef_id,chef_name,status,total_amount,created_at,updated_at,delivery_address,notes';
    final q = searchQuery?.trim() ?? '';
    final chef = chefIdEq?.trim();
    final cust = customerIdEq?.trim();
    final useServerFilters = q.isEmpty;

    final List<dynamic> rows;
    if (q.isEmpty) {
      var qb = _sb.from('orders').select(sel);
      if (chef != null && chef.isNotEmpty) {
        qb = qb.eq('chef_id', chef);
      }
      if (cust != null && cust.isNotEmpty) {
        qb = qb.eq('customer_id', cust);
      }
      if (createdAfter != null) {
        qb = qb.gte('created_at', createdAfter.toUtc().toIso8601String());
      }
      if (createdBefore != null) {
        final end = DateTime(createdBefore.year, createdBefore.month, createdBefore.day, 23, 59, 59, 999);
        qb = qb.lte('created_at', end.toUtc().toIso8601String());
      }
      rows = await qb.order('created_at', ascending: false).range(from, to) as List<dynamic>;
    } else {
      final safe = _adminSanitizeIlike(q);
      if (safe.isEmpty) return const [];
      final p = '%$safe%';
      final parts = <String>[
        'customer_name.ilike.$p',
        'chef_name.ilike.$p',
      ];
      if (_adminIsFullOrderUuid(q)) {
        parts.add('id.eq.${q.trim()}');
      } else {
        parts.add('id::text.ilike.$p');
      }
      rows = await _sb
          .from('orders')
          .select(sel)
          .or(parts.join(','))
          .order('created_at', ascending: false)
          .range(from, to) as List<dynamic>;
    }

    var list = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    if (!useServerFilters && (chef != null && chef.isNotEmpty || cust != null && cust.isNotEmpty || createdAfter != null || createdBefore != null)) {
      list = list.where((r) {
        if (chef != null && chef.isNotEmpty && (r['chef_id'] ?? '').toString() != chef) return false;
        if (cust != null && cust.isNotEmpty && (r['customer_id'] ?? '').toString() != cust) return false;
        final ca = DateTime.tryParse((r['created_at'] ?? '').toString());
        if (ca == null) return true;
        if (createdAfter != null && ca.isBefore(createdAfter)) return false;
        if (createdBefore != null) {
          final end = DateTime(createdBefore.year, createdBefore.month, createdBefore.day, 23, 59, 59, 999);
          if (ca.isAfter(end)) return false;
        }
        return true;
      }).toList();
    }

    await _attachLastChatSnippetsToOrders(list);
    return list;
  }

  /// Best-effort: last message text from the customer–cook thread for each order (for compact admin lists).
  Future<void> _attachLastChatSnippetsToOrders(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final orderIds = rows.map((e) => (e['id'] ?? '').toString()).where((x) => x.isNotEmpty).toList();
    if (orderIds.isEmpty) return;
    try {
      final convRows = await _sb
          .from('conversations')
          .select('id,order_id')
          .eq('type', 'customer-chef')
          .inFilter('order_id', orderIds);
      final orderToConv = <String, String>{};
      final convIdSet = <String>{};
      for (final raw in convRows as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final oid = (m['order_id'] ?? '').toString();
        final cid = (m['id'] ?? '').toString();
        if (oid.isEmpty || cid.isEmpty) continue;
        orderToConv[oid] = cid;
        convIdSet.add(cid);
      }
      if (convIdSet.isEmpty) return;
      final convIds = convIdSet.toList();
      final msgRows = await _sb
          .from('messages')
          .select('conversation_id,content,created_at')
          .inFilter('conversation_id', convIds)
          .order('created_at', ascending: false)
          .limit(1000);
      final previewByConv = <String, String>{};
      for (final raw in msgRows as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final cid = (m['conversation_id'] ?? '').toString();
        if (cid.isEmpty || previewByConv.containsKey(cid)) continue;
        final c = (m['content'] ?? '').toString().trim();
        previewByConv[cid] = c.isEmpty ? '—' : (c.length > 80 ? '${c.substring(0, 80)}…' : c);
      }
      for (final r in rows) {
        final oid = (r['id'] ?? '').toString();
        final cid = orderToConv[oid];
        if (cid == null) continue;
        final p = previewByConv[cid];
        if (p != null) r['_last_message_preview'] = p;
      }
    } catch (e, st) {
      debugPrint('[Admin] last chat snippets: $e\n$st');
    }
  }

  /// Per [menu_item_id] order line counts for a cook (completed pipeline orders only).
  Future<Map<String, int>> fetchOrderCountsByMenuItemForCook(String cookId) async {
    final id = cookId.trim();
    if (id.isEmpty) return const {};
    try {
      final ord = await _sb.from('orders').select('id').eq('chef_id', id).eq('status', 'completed').limit(400);
      final ids = (ord as List?)
              ?.map((e) => (e as Map)['id']?.toString())
              .whereType<String>()
              .where((x) => x.isNotEmpty)
              .toList() ??
          const <String>[];
      if (ids.isEmpty) return const {};
      final items = await _sb.from('order_items').select('menu_item_id, quantity').inFilter('order_id', ids);
      final counts = <String, int>{};
      for (final raw in items as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final mid = (m['menu_item_id'] ?? '').toString();
        if (mid.isEmpty) continue;
        final q = (m['quantity'] as num?)?.toInt() ?? 1;
        counts[mid] = (counts[mid] ?? 0) + q;
      }
      return counts;
    } catch (e, st) {
      debugPrint('[Admin] fetchOrderCountsByMenuItemForCook: $e\n$st');
      return const {};
    }
  }

  /// Top dish lines by name for a cook (completed orders).
  Future<List<Map<String, dynamic>>> fetchTopDishLinesForCook(String cookId, {int limit = 8}) async {
    final id = cookId.trim();
    if (id.isEmpty) return const [];
    try {
      final ord = await _sb.from('orders').select('id').eq('chef_id', id).eq('status', 'completed').limit(400);
      final ids = (ord as List?)
              ?.map((e) => (e as Map)['id']?.toString())
              .whereType<String>()
              .toList() ??
          const <String>[];
      if (ids.isEmpty) return const [];
      final items = await _sb.from('order_items').select('dish_name, quantity').inFilter('order_id', ids);
      final tally = <String, int>{};
      for (final raw in items as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final name = (m['dish_name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final q = (m['quantity'] as num?)?.toInt() ?? 1;
        tally[name] = (tally[name] ?? 0) + q;
      }
      final sorted = tally.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return sorted
          .take(limit)
          .map((e) => <String, dynamic>{'dish_name': e.key, 'quantity_sold': e.value})
          .toList();
    } catch (e, st) {
      debugPrint('[Admin] fetchTopDishLinesForCook: $e\n$st');
      return const [];
    }
  }

  /// Best-effort activity feed from existing tables (no dedicated audit log required).
  Future<List<Map<String, dynamic>>> fetchCookActivityTimelineRows(String cookId) async {
    final id = cookId.trim();
    if (id.isEmpty) return const [];
    final events = <Map<String, dynamic>>[];
    try {
      final prof = await _sb.from('profiles').select('created_at, full_name').eq('id', id).maybeSingle();
      if (prof != null) {
        final m = Map<String, dynamic>.from(prof as Map);
        final ca = m['created_at'];
        if (ca != null) {
          events.add({
            'at': ca,
            'kind': 'account',
            'title': 'Account created',
            'subtitle': (m['full_name'] ?? '').toString(),
          });
        }
      }
    } catch (e, st) {
      debugPrint('[Admin] timeline profile: $e\n$st');
    }
    try {
      final cp = await _sb
          .from('chef_profiles')
          .select('approval_status, updated_at')
          .eq('id', id)
          .maybeSingle();
      if (cp != null) {
        final m = Map<String, dynamic>.from(cp as Map);
        final ast = (m['approval_status'] ?? '').toString().toLowerCase();
        if (ast.contains('approved')) {
          events.add({
            'at': m['updated_at'],
            'kind': 'approval',
            'title': 'Cook application approved',
            'subtitle': (m['approval_status'] ?? '').toString(),
          });
        }
      }
    } catch (e, st) {
      debugPrint('[Admin] timeline chef_profiles: $e\n$st');
    }
    try {
      final docs = await _sb
          .from('chef_documents')
          .select('created_at, updated_at, document_type, status')
          .eq('chef_id', id)
          .order('created_at', ascending: false)
          .limit(40);
      for (final raw in docs as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final st = (m['status'] ?? '').toString();
        final dt = (m['document_type'] ?? '').toString();
        final at = m['updated_at'] ?? m['created_at'];
        var title = 'Document: $dt';
        if (st.toLowerCase() == 'approved') {
          title = 'Document approved · $dt';
        } else if (st.toLowerCase() == 'rejected') {
          title = 'Document rejected · $dt';
        } else if (st.toLowerCase() == 'pending') {
          title = 'Document uploaded / pending · $dt';
        }
        events.add({'at': at, 'kind': 'document', 'title': title, 'subtitle': 'Status: $st'});
      }
    } catch (e, st) {
      debugPrint('[Admin] timeline docs: $e\n$st');
    }
    try {
      final reels = await _sb
          .from('reels')
          .select('created_at, caption')
          .eq('chef_id', id)
          .order('created_at', ascending: false)
          .limit(20);
      for (final raw in reels as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        events.add({
          'at': m['created_at'],
          'kind': 'reel',
          'title': 'Reel posted',
          'subtitle': (m['caption'] ?? '').toString().trim().isEmpty ? '—' : (m['caption'] ?? '').toString(),
        });
      }
    } catch (e, st) {
      debugPrint('[Admin] timeline reels: $e\n$st');
    }
    try {
      final dishes = await _sb
          .from('menu_items')
          .select('created_at, name')
          .eq('chef_id', id)
          .order('created_at', ascending: false)
          .limit(20);
      for (final raw in dishes as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        events.add({
          'at': m['created_at'],
          'kind': 'dish',
          'title': 'Dish added',
          'subtitle': (m['name'] ?? '').toString(),
        });
      }
    } catch (e, st) {
      debugPrint('[Admin] timeline menu: $e\n$st');
    }
    try {
      final audit = await _sb.rpc<dynamic>(
        'get_admin_logs_for_cook',
        params: {'p_cook_id': id, 'p_limit': 80},
      );
      final list = audit is List ? audit : const <dynamic>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final action = (m['action'] ?? '').toString();
        events.add({
          'at': m['created_at'],
          'kind': 'audit',
          'title': _adminAuditTimelineTitle(action),
          'subtitle': _adminAuditTimelineSubtitle(m),
        });
      }
    } catch (e, st) {
      debugPrint('[Admin] timeline audit RPC skipped (run supabase_admin_moderation_extensions.sql): $e\n$st');
    }
    events.sort((a, b) {
      final ta = DateTime.tryParse((a['at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse((b['at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return events;
  }

  String _adminAuditTimelineTitle(String action) {
    switch (action) {
      case 'cook_document_approved':
        return 'Application document approved';
      case 'cook_document_rejected':
        return 'Application document rejected';
      case 'cook_frozen':
        return 'Cook frozen';
      case 'cook_unfrozen':
        return 'Cook unfrozen';
      case 'cook_warning':
        return 'Warning issued to cook';
      case 'reel_hidden':
        return 'Reel hidden by admin';
      case 'reel_unhidden':
        return 'Reel unhidden by admin';
      case 'reel_removed':
        return 'Reel removed by admin';
      case 'conversation_moderation_updated':
        return 'Conversation moderation updated';
      default:
        if (action.isEmpty) return 'Admin action';
        return action.replaceAll('_', ' ');
    }
  }

  String _adminAuditTimelineSubtitle(Map<String, dynamic> row) {
    final tt = (row['target_table'] ?? '').toString();
    final tid = (row['target_id'] ?? '').toString();
    final payload = row['payload'];
    if (payload is Map) {
      final p = Map<String, dynamic>.from(payload);
      final reason = (p['reason'] ?? '').toString();
      if (reason.isNotEmpty) return reason;
    }
    if (tt.isNotEmpty && tid.isNotEmpty) return '$tt · $tid';
    return tt.isNotEmpty ? tt : '—';
  }

  /// [support_tickets] preview for admin dashboard (optional table).
  Future<({List<Map<String, dynamic>> rows, bool backendAvailable})> fetchSupportTicketsPreviewForAdmin({
    int limit = 10,
  }) async {
    try {
      final rows = await _sb
          .from('support_tickets')
          .select('id,status,subject,created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return (rows: list, backendAvailable: true);
    } catch (e, st) {
      debugPrint('[Admin] support_tickets preview: $e\n$st');
      return (rows: <Map<String, dynamic>>[], backendAvailable: false);
    }
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

  /// Merges [warning_count] / [freeze_until] into [profiles] rows (role chef) for admin UI.
  /// Avoids embedded [profiles]→[chef_profiles] selects (PostgREST relationship hints can 400).
  Future<void> _enrichChefProfilesForAdmin(List<Map<String, dynamic>> profiles) async {
    if (profiles.isEmpty) return;
    final chefIds = <String>{};
    for (final r in profiles) {
      if ((r['role'] ?? '').toString() != 'chef') continue;
      final id = (r['id'] ?? '').toString();
      if (id.isNotEmpty) chefIds.add(id);
    }
    if (chefIds.isEmpty) return;
    try {
      final cps = await _sb
          .from('chef_profiles')
          .select('id, warning_count, freeze_level, freeze_until, freeze_type, freeze_started_at, freeze_reason')
          .inFilter('id', chefIds.toList());
      final byId = <String, Map<String, dynamic>>{};
      for (final raw in cps as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) continue;
        byId[id] = {
          'warning_count': m['warning_count'],
          'freeze_level': m['freeze_level'],
          'freeze_until': m['freeze_until'],
          'freeze_type': m['freeze_type'],
          'freeze_started_at': m['freeze_started_at'],
          'freeze_reason': m['freeze_reason'],
        };
      }
      for (final r in profiles) {
        if ((r['role'] ?? '').toString() != 'chef') continue;
        final id = (r['id'] ?? '').toString();
        final cp = byId[id];
        if (cp != null) r['chef_profiles'] = cp;
      }
    } catch (e, st) {
      debugPrint('[Admin] enrichChefProfilesForAdmin: $e\n$st');
    }
  }

  /// Recent [profiles] rows for admin directory (RLS: admin SELECT all).
  /// [searchQuery]: matches [full_name], [phone], or chefs by [chef_profiles.kitchen_name].
  Future<List<Map<String, dynamic>>> fetchProfilesForAdmin({
    int limit = 200,
    int offset = 0,
    String? searchQuery,
  }) async {
    if (limit <= 0) return const [];
    final sel = await _resolveProfilesSelect();
    final q = searchQuery?.trim() ?? '';
    if (q.isEmpty) {
      final from = offset;
      final to = offset + limit - 1;
      final rows = await _sb
          .from('profiles')
          .select(sel)
          .order('full_name', ascending: true)
          .range(from, to);
      final list = (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _enrichChefProfilesForAdmin(list);
      return list;
    }

    final safe = _adminSanitizeIlike(q);
    if (safe.isEmpty) return const [];

    final p = '%$safe%';
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    void addRows(List<dynamic> list) {
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        merged.add(m);
      }
    }

    final byText = await _sb
        .from('profiles')
        .select(sel)
        .or('full_name.ilike.$p,phone.ilike.$p,id::text.ilike.$p')
        .order('full_name', ascending: true)
        .limit(limit);

    addRows(byText as List? ?? const []);

    final chefMatch = await _sb
        .from('chef_profiles')
        .select('id')
        .ilike('kitchen_name', p)
        .limit(limit);

    final chefIds = (chefMatch as List?)
            ?.map((e) => (e as Map)['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList() ??
        const <String>[];

    if (chefIds.isNotEmpty) {
      final byChef = await _sb
          .from('profiles')
          .select(sel)
          .inFilter('id', chefIds)
          .order('full_name', ascending: true)
          .limit(limit);
      addRows(byChef as List? ?? const []);
    }

    merged.sort((a, b) {
      final na = (a['full_name'] ?? '').toString().toLowerCase();
      final nb = (b['full_name'] ?? '').toString().toLowerCase();
      return na.compareTo(nb);
    });

    final List<Map<String, dynamic>> out;
    if (merged.length > limit) {
      out = merged.sublist(0, limit);
    } else {
      out = merged;
    }
    await _enrichChefProfilesForAdmin(out);
    return out;
  }

  /// Sets [profiles.is_blocked] for [profileId]. [currentAdminId] must match the signed-in admin (caller-supplied for UX checks).
  Future<void> setProfileBlockedForAdmin({
    required String profileId,
    required bool blocked,
    required String currentAdminId,
  }) async {
    final pid = profileId.trim();
    final aid = currentAdminId.trim();
    if (pid.isEmpty) throw ArgumentError('profileId required');
    if (aid.isEmpty) throw ArgumentError('currentAdminId required');
    if (pid == aid) {
      throw Exception('You cannot change the blocked status of your own account here.');
    }
    await _sb.from('profiles').update({'is_blocked': blocked}).eq('id', pid);
  }

  Future<List<Map<String, dynamic>>> fetchAllReelsForAdmin({int limit = 500}) async {
    if (limit <= 0) return const [];
    const selFull =
        'id,chef_id,video_url,thumbnail_url,caption,dish_id,created_at,is_hidden';
    const selBase = 'id,chef_id,video_url,thumbnail_url,caption,dish_id,created_at';
    List<dynamic> rows;
    try {
      rows = await _sb.from('reels').select(selFull).order('created_at', ascending: false).limit(limit) as List<dynamic>;
    } catch (e, st) {
      debugPrint('[Admin] reels select is_hidden missing? retry base columns: $e\n$st');
      rows = await _sb.from('reels').select(selBase).order('created_at', ascending: false).limit(limit) as List<dynamic>;
    }
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
    try {
      final ids = list.map((e) => (e['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      if (ids.isNotEmpty) {
        final reports = await _sb.from('reel_reports').select('reel_id').inFilter('reel_id', ids);
        final tally = <String, int>{};
        for (final raw in reports as List) {
          final m = Map<String, dynamic>.from(raw as Map);
          final rid = (m['reel_id'] ?? '').toString();
          if (rid.isEmpty) continue;
          tally[rid] = (tally[rid] ?? 0) + 1;
        }
        final reasonFirst = <String, String>{};
        try {
          final detailed = await _sb
              .from('reel_reports')
              .select('reel_id,reason,created_at')
              .inFilter('reel_id', ids)
              .order('created_at', ascending: false);
          for (final raw in detailed as List) {
            final m = Map<String, dynamic>.from(raw as Map);
            final rid = (m['reel_id'] ?? '').toString();
            if (rid.isEmpty) continue;
            reasonFirst.putIfAbsent(rid, () {
              final rs = (m['reason'] ?? '').toString().trim();
              return rs.isNotEmpty ? rs : 'Reported';
            });
          }
        } catch (e, st) {
          debugPrint('[Admin] reel report reasons skipped: $e\n$st');
        }
        for (final r in list) {
          final id = (r['id'] ?? '').toString();
          r['report_count'] = tally[id] ?? 0;
          r['report_reason_preview'] = reasonFirst[id] ?? '';
        }
      }
    } catch (e, st) {
      debugPrint('[Admin] reel report counts skipped: $e\n$st');
      for (final r in list) {
        r['report_count'] = r['report_count'] ?? 0;
        r['report_reason_preview'] = r['report_reason_preview'] ?? '';
      }
    }
    for (final r in list) {
      r['is_hidden'] = r['is_hidden'] == true;
    }
    return list;
  }

  /// Requires [reels.is_hidden] and RLS [reels_update_admin] (see supabase_admin_moderation_extensions.sql).
  Future<void> setReelHiddenForAdmin({required String reelId, required bool hidden}) async {
    final id = reelId.trim();
    if (id.isEmpty) return;
    await _sb.from('reels').update({'is_hidden': hidden}).eq('id', id);
  }

  /// Requires [conversations.admin_moderation_state], [admin_reviewed_at] and [conversations_update_admin].
  Future<void> updateConversationModerationForAdmin({
    required String conversationId,
    String? moderationState,
    bool? markReviewedNow,
    bool clearReviewedAt = false,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    final u = <String, dynamic>{};
    if (moderationState != null) u['admin_moderation_state'] = moderationState;
    if (markReviewedNow == true) {
      u['admin_reviewed_at'] = DateTime.now().toUtc().toIso8601String();
    } else if (clearReviewedAt) {
      u['admin_reviewed_at'] = null;
    }
    if (u.isEmpty) return;
    await _sb.from('conversations').update(u).eq('id', id);
  }

  // ─── Production analytics RPCs (see supabase_admin_production_analytics.sql) ─

  Future<Map<String, dynamic>> getAdminAnalyticsBundle({
    int dailyDays = 30,
    int monthlyMonths = 6,
    int hourLookbackDays = 30,
  }) async {
    try {
      final result = await _sb.rpc<dynamic>(
        'get_admin_analytics_bundle',
        params: {
          'p_daily_days': dailyDays,
          'p_monthly_months': monthlyMonths,
          'p_hour_lookback_days': hourLookbackDays,
        },
      );
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e, st) {
      debugPrint('[Admin] get_admin_analytics_bundle: $e\n$st');
    }
    return {};
  }

  Future<Map<String, dynamic>> getAdminAlertsSummary() async {
    try {
      final result = await _sb.rpc<dynamic>('get_admin_alerts_summary');
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e, st) {
      debugPrint('[Admin] get_admin_alerts_summary: $e\n$st');
    }
    return {};
  }

  Future<Map<String, dynamic>> getAdminUserDetail(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return {'error': 'invalid_id'};
    try {
      final result = await _sb.rpc<dynamic>(
        'get_admin_user_detail',
        params: {'p_user_id': id},
      );
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e, st) {
      debugPrint('[Admin] get_admin_user_detail: $e\n$st');
      return {'error': e.toString()};
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> fetchMenuItemsForCook(String cookId) async {
    if (cookId.isEmpty) return const [];
    try {
      final rows = await _sb
          .from('menu_items')
          .select(
            'id,chef_id,name,description,price,is_available,moderation_status,created_at,daily_quantity,remaining_quantity',
          )
          .eq('chef_id', cookId)
          .order('name', ascending: true);
      return (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('[Admin] fetchMenuItemsForCook: $e\n$st');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchChefDocumentsAllForAdmin(String cookId) async {
    if (cookId.isEmpty) return const [];
    try {
      final rows = await _sb
          .from('chef_documents')
          .select(
            'id,chef_id,document_type,status,file_url,expiry_date,no_expiry,rejection_reason,reviewed_at,created_at,updated_at',
          )
          .eq('chef_id', cookId)
          .order('created_at', ascending: false);
      return (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('[Admin] fetchChefDocumentsAllForAdmin: $e\n$st');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrdersForUserRole({
    required String userId,
    required String role,
    int limit = 80,
  }) async {
    if (userId.isEmpty || limit <= 0) return const [];
    final col = role == 'chef' ? 'chef_id' : 'customer_id';
    try {
      final rows = await _sb
          .from('orders')
          .select(
            'id,customer_id,customer_name,chef_id,chef_name,status,total_amount,created_at,updated_at',
          )
          .eq(col, userId)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _attachLastChatSnippetsToOrders(list);
      return list;
    } catch (e, st) {
      debugPrint('[Admin] fetchOrdersForUserRole: $e\n$st');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchReelsForCook(String cookId, {int limit = 50}) async {
    if (cookId.isEmpty) return const [];
    try {
      final rows = await _sb
          .from('reels')
          .select('id,chef_id,video_url,thumbnail_url,caption,dish_id,created_at')
          .eq('chef_id', cookId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('[Admin] fetchReelsForCook: $e\n$st');
      return const [];
    }
  }

  /// General escalation ladder from the cook profile (one automatic step per call). **Not** for live
  /// kitchen inspections — use [finalizeInspectionOutcome] there (outcome only).
  Future<Map<String, dynamic>> adminChefTakeEnforcementAction(String cookId) async {
    final id = cookId.trim();
    if (id.isEmpty) throw ArgumentError('cookId required');
    final result = await _sb.rpc<dynamic>(
      'admin_chef_take_enforcement_action',
      params: {'p_cook_id': id},
    );
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return <String, dynamic>{'raw': result};
  }

  Future<List<Map<String, dynamic>>> fetchExpiredDocumentsForAdmin({int limit = 50}) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().split('T').first;
      final rows = await _sb
          .from('chef_documents')
          .select(
            'id,chef_id,document_type,status,expiry_date,created_at',
          )
          .eq('status', 'approved')
          .lt('expiry_date', today)
          .order('expiry_date', ascending: true)
          .limit(limit);
      return (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('[Admin] fetchExpiredDocumentsForAdmin: $e\n$st');
      return const [];
    }
  }
}
