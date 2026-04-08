import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_providers.dart';

DateTime _parseDt(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

/// Admin inbox: [chef-admin] threads (cook ↔ admin support). Not customer–chef order chats.
final adminChefSupportInboxStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final ok = ref.watch(isAdminProvider);
  if (!ok) return const Stream<List<Map<String, dynamic>>>.empty();
  return _adminInboxStream(
    conversationType: 'chef-admin',
    titleForRow: (row, kitchenByChef, profileNames) {
      final chefId = (row['chef_id'] ?? '').toString();
      final kn = kitchenByChef[chefId];
      if (kn != null && kn.isNotEmpty) return kn;
      return chefId.isEmpty ? 'Cook' : 'Cook $chefId';
    },
  );
});

/// Admin inbox: [customer-support] threads (customer ↔ admin: complaints, questions).
final adminCustomerSupportInboxStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final ok = ref.watch(isAdminProvider);
  if (!ok) return const Stream<List<Map<String, dynamic>>>.empty();
  return _adminInboxStream(
    conversationType: 'customer-support',
    titleForRow: (row, kitchenByChef, profileNames) {
      final customerId = (row['customer_id'] ?? '').toString();
      final name = profileNames[customerId];
      if (name != null && name.isNotEmpty) return name;
      return customerId.isEmpty ? 'Customer' : 'Customer $customerId';
    },
  );
});

Stream<List<Map<String, dynamic>>> _adminInboxStream({
  required String conversationType,
  required String Function(
    Map<String, dynamic> row,
    Map<String, String> kitchenByChef,
    Map<String, String> profileNames,
  ) titleForRow,
}) {
  return Supabase.instance.client
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((rows) async {
    final scoped = rows
        .where((r) => (r['type']?.toString() ?? '') == conversationType)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    final ids = scoped
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final lastByConv = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      try {
        final msgRows = await Supabase.instance.client
            .from('messages')
            .select('conversation_id,sender_id,content,created_at')
            .inFilter('conversation_id', ids)
            .order('created_at', ascending: false);
        for (final raw in (msgRows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final cid = (m['conversation_id'] ?? '').toString();
          if (cid.isEmpty) continue;
          lastByConv.putIfAbsent(cid, () => m);
        }
      } catch (e, st) {
        debugPrint('[AdminSupportInbox] load last messages: $e\n$st');
      }
    }

    final customerIds = scoped
        .map((r) => (r['customer_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final chefIds = scoped
        .map((r) => (r['chef_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profileNames = <String, String>{};
    try {
      final needProfiles = <String>{...customerIds, ...chefIds}.toList();
      if (needProfiles.isNotEmpty) {
        final pr = await Supabase.instance.client
            .from('profiles')
            .select('id,full_name')
            .inFilter('id', needProfiles);
        for (final raw in (pr as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] ?? '').toString();
          final name = (row['full_name'] ?? '').toString().trim();
          if (id.isNotEmpty && name.isNotEmpty) profileNames[id] = name;
        }
      }
    } catch (e, st) {
      debugPrint('[AdminSupportInbox] profiles: $e\n$st');
    }

    final kitchenNames = <String, String>{};
    try {
      if (chefIds.isNotEmpty) {
        final ch = await Supabase.instance.client
            .from('chef_profiles')
            .select('id,kitchen_name')
            .inFilter('id', chefIds);
        for (final raw in (ch as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] ?? '').toString();
          final name = (row['kitchen_name'] ?? '').toString().trim();
          if (id.isNotEmpty && name.isNotEmpty) kitchenNames[id] = name;
        }
      }
    } catch (e, st) {
      debugPrint('[AdminSupportInbox] chef_profiles: $e\n$st');
    }

    scoped.sort((a, b) {
      final ida = (a['id'] ?? '').toString();
      final idb = (b['id'] ?? '').toString();
      final la = lastByConv[ida];
      final lb = lastByConv[idb];
      final ca = la != null ? _parseDt(la['created_at']) : _parseDt(a['created_at']);
      final cb = lb != null ? _parseDt(lb['created_at']) : _parseDt(b['created_at']);
      return cb.compareTo(ca);
    });

    return scoped.map((row) {
      final id = (row['id'] ?? '').toString();
      final latest = lastByConv[id];
      final lastMsg = (latest?['content'] ?? '').toString().trim();
      final lastAt = latest != null ? _parseDt(latest['created_at']) : _parseDt(row['created_at']);
      final title = titleForRow(row, kitchenNames, profileNames);
      return {
        'id': id,
        'title': title,
        'lastMessage': lastMsg.isEmpty ? '—' : lastMsg,
        'lastMessageAt': lastAt,
        'type': conversationType,
        'admin_moderation_state': (row['admin_moderation_state'] ?? 'none').toString(),
        'admin_reviewed_at': row['admin_reviewed_at'],
      };
    }).toList();
  });
}

String _orderRefLabel(String? orderUuid) {
  final u = orderUuid?.trim() ?? '';
  if (u.length < 8) return u.isEmpty ? '—' : u;
  return '#${u.substring(0, 8).toUpperCase()}';
}

String _monitorStatusEn(String? dbStatus) {
  final s = dbStatus?.trim() ?? '';
  if (s.isEmpty) return '—';
  if (s == 'paid_waiting_acceptance' || s == 'pending') return 'Awaiting cook';
  if (s == 'accepted') return 'Accepted';
  if (s == 'preparing') return 'Preparing';
  if (s == 'ready') return 'Ready for pickup';
  if (s == 'completed') return 'Completed';
  if (s.startsWith('cancelled') || s == 'rejected') return 'Cancelled';
  if (s == 'expired') return 'Expired';
  return s;
}

/// Customer ↔ cook threads tied to orders (admin monitoring).
final adminOrderMonitorChatsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final ok = ref.watch(isAdminProvider);
  if (!ok) return const Stream<List<Map<String, dynamic>>>.empty();

  return Supabase.instance.client
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((rows) async {
    final scoped = rows
        .where((r) => (r['type']?.toString() ?? '') == 'customer-chef')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    final ids = scoped
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final lastByConv = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      try {
        final msgRows = await Supabase.instance.client
            .from('messages')
            .select('conversation_id,sender_id,content,created_at')
            .inFilter('conversation_id', ids)
            .order('created_at', ascending: false);
        for (final raw in (msgRows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final cid = (m['conversation_id'] ?? '').toString();
          if (cid.isEmpty) continue;
          lastByConv.putIfAbsent(cid, () => m);
        }
      } catch (e, st) {
        debugPrint('[AdminOrderMonitor] messages: $e\n$st');
      }
    }

    final customerIds = scoped
        .map((r) => (r['customer_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final chefIds = scoped
        .map((r) => (r['chef_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profileNames = <String, String>{};
    try {
      final need = <String>{...customerIds, ...chefIds}.toList();
      if (need.isNotEmpty) {
        final pr = await Supabase.instance.client
            .from('profiles')
            .select('id,full_name')
            .inFilter('id', need);
        for (final raw in (pr as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] ?? '').toString();
          final name = (row['full_name'] ?? '').toString().trim();
          if (id.isNotEmpty && name.isNotEmpty) profileNames[id] = name;
        }
      }
    } catch (e, st) {
      debugPrint('[AdminOrderMonitor] profiles: $e\n$st');
    }

    final kitchenNames = <String, String>{};
    try {
      if (chefIds.isNotEmpty) {
        final ch = await Supabase.instance.client
            .from('chef_profiles')
            .select('id,kitchen_name')
            .inFilter('id', chefIds);
        for (final raw in (ch as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] ?? '').toString();
          final name = (row['kitchen_name'] ?? '').toString().trim();
          if (id.isNotEmpty && name.isNotEmpty) kitchenNames[id] = name;
        }
      }
    } catch (e, st) {
      debugPrint('[AdminOrderMonitor] chef_profiles: $e\n$st');
    }

    final orderIds = scoped
        .map((r) => r['order_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final orderById = <String, Map<String, dynamic>>{};
    if (orderIds.isNotEmpty) {
      try {
        final orows = await Supabase.instance.client
            .from('orders')
            .select('id,status,delivery_address,customer_name,chef_name')
            .inFilter('id', orderIds);
        for (final raw in (orows as List)) {
          final o = Map<String, dynamic>.from(raw as Map);
          final oid = (o['id'] ?? '').toString();
          if (oid.isNotEmpty) orderById[oid] = o;
        }
      } catch (e, st) {
        debugPrint('[AdminOrderMonitor] orders: $e\n$st');
      }
    }

    scoped.sort((a, b) {
      final ida = (a['id'] ?? '').toString();
      final idb = (b['id'] ?? '').toString();
      final la = lastByConv[ida];
      final lb = lastByConv[idb];
      final ca = la != null ? _parseDt(la['created_at']) : _parseDt(a['created_at']);
      final cb = lb != null ? _parseDt(lb['created_at']) : _parseDt(b['created_at']);
      return cb.compareTo(ca);
    });

    final now = DateTime.now();
    return scoped.map((row) {
      final id = (row['id'] ?? '').toString();
      final customerId = (row['customer_id'] ?? '').toString();
      final chefId = (row['chef_id'] ?? '').toString();
      final orderId = row['order_id']?.toString();
      final latest = lastByConv[id];
      final lastMsg = (latest?['content'] ?? '').toString().trim();
      final lastAt = latest != null ? _parseDt(latest['created_at']) : _parseDt(row['created_at']);
      final activeNow = now.difference(lastAt).inMinutes <= 20;

      final o = (orderId != null && orderId.isNotEmpty) ? orderById[orderId] : null;
      final custFromOrder = (o?['customer_name'] ?? '').toString().trim();
      final chefFromOrder = (o?['chef_name'] ?? '').toString().trim();
      final customerLabel = custFromOrder.isNotEmpty
          ? custFromOrder
          : (profileNames[customerId] ?? 'Customer');
      final cookKitchen = kitchenNames[chefId] ?? '';
      final cookProfile = profileNames[chefId] ?? '';
      final cookLabel = cookKitchen.isNotEmpty
          ? cookKitchen
          : (chefFromOrder.isNotEmpty ? chefFromOrder : cookProfile);
      final location = (o?['delivery_address'] ?? '').toString().trim();
      final statusDb = (o?['status'] ?? '').toString();

      return {
        'id': id,
        'conversationId': id,
        'orderId': orderId ?? '',
        'orderRef': _orderRefLabel(orderId),
        'customerLabel': customerLabel,
        'cookLabel': cookLabel.isEmpty ? 'Cook' : cookLabel,
        'location': location.isEmpty ? '—' : location,
        'statusDb': statusDb,
        'statusLabel': _monitorStatusEn(statusDb),
        'activeNow': activeNow,
        'lastMessage': lastMsg.isEmpty ? '—' : lastMsg,
        'lastMessageAt': lastAt,
        'admin_moderation_state': (row['admin_moderation_state'] ?? 'none').toString(),
        'admin_reviewed_at': row['admin_reviewed_at'],
        'title': '${_orderRefLabel(orderId)} · $customerLabel ↔ $cookLabel',
      };
    }).toList();
  });
});
