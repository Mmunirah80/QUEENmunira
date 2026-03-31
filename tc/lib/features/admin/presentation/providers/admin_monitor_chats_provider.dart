import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_providers.dart';

DateTime _parseDt(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

/// All customer–chef threads (admin monitoring). RLS must allow admin SELECT on [conversations] / [messages].
final adminCustomerChefChatsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final ok = ref.watch(isAdminProvider);
  if (!ok) return const Stream<List<Map<String, dynamic>>>.empty();

  return Supabase.instance.client
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((rows) async {
    final scoped = rows
        .where((r) => (r['type']?.toString() ?? '') == 'customer-chef')
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
          final m = raw as Map<String, dynamic>;
          final cid = (m['conversation_id'] ?? '').toString();
          if (cid.isEmpty) continue;
          lastByConv.putIfAbsent(cid, () => m);
        }
      } catch (e, st) {
        debugPrint('[AdminMonitorChats] load last messages: $e\n$st');
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
      if (customerIds.isNotEmpty) {
        final pr = await Supabase.instance.client
            .from('profiles')
            .select('id,full_name')
            .inFilter('id', customerIds);
        for (final raw in (pr as List)) {
          final row = raw as Map<String, dynamic>;
          final id = (row['id'] ?? '').toString();
          final name = (row['full_name'] ?? '').toString().trim();
          if (id.isNotEmpty && name.isNotEmpty) profileNames[id] = name;
        }
      }
    } catch (e, st) {
      debugPrint('[AdminMonitorChats] profiles: $e\n$st');
    }

    final kitchenNames = <String, String>{};
    try {
      if (chefIds.isNotEmpty) {
        final ch = await Supabase.instance.client
            .from('chef_profiles')
            .select('id,kitchen_name')
            .inFilter('id', chefIds);
        for (final raw in (ch as List)) {
          final row = raw as Map<String, dynamic>;
          final id = (row['id'] ?? '').toString();
          final name = (row['kitchen_name'] ?? '').toString().trim();
          if (id.isNotEmpty && name.isNotEmpty) kitchenNames[id] = name;
        }
      }
    } catch (e, st) {
      debugPrint('[AdminMonitorChats] chef_profiles: $e\n$st');
    }

    scoped.sort((a, b) {
      final ca = _parseDt(a['created_at']);
      final cb = _parseDt(b['created_at']);
      return cb.compareTo(ca);
    });

    return scoped.map((row) {
      final id = (row['id'] ?? '').toString();
      final customerId = (row['customer_id'] ?? '').toString();
      final chefId = (row['chef_id'] ?? '').toString();
      final orderId = row['order_id']?.toString();
      final custName = profileNames[customerId] ?? 'Customer';
      final cookName = kitchenNames[chefId] ?? 'Cook';
      final latest = lastByConv[id];
      final lastMsg = (latest?['content'] ?? '').toString().trim();
      final lastAt = latest != null ? _parseDt(latest['created_at']) : _parseDt(row['created_at']);
      return {
        'id': id,
        'customerId': customerId,
        'chefId': chefId,
        'customerLabel': custName,
        'cookLabel': cookName,
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        'lastMessage': lastMsg.isEmpty ? '—' : lastMsg,
        'lastMessageAt': lastAt,
        'title': '$custName ↔ $cookName',
      };
    }).toList();
  });
});
