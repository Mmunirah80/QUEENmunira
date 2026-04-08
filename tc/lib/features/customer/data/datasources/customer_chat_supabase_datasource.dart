// ============================================================
// Customer Chat — Supabase conversations + messages.
// conversations: id, type, customer_id, chef_id, admin_id, created_at
// messages: id, conversation_id, sender_id, content, is_read, created_at, topic, extension, event, payload, private, updated_at, inserted_at
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/supabase/supabase_auth_user_id.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../chat/data/chat_limits.dart';

typedef _LatestMsg = ({String content, DateTime? at});

class CustomerChatSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.dataClient;

  /// When DB has duplicate rows (same customer + chef), `.maybeSingle()` throws 406.
  /// Always take the latest row by `created_at`.
  Future<String?> _latestCustomerChefConversationId({
    required String customerId,
    required String chefId,
  }) async {
    final res = await _sb
        .from('conversations')
        .select('id')
        .eq('customer_id', customerId)
        .eq('chef_id', chefId)
        .eq('type', 'customer-chef')
        .order('created_at', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(res as List);
    if (list.isEmpty) return null;
    final id = list.first['id'] as String?;
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<String?> _latestCustomerSupportConversationId(String customerId) async {
    final res = await _sb
        .from('conversations')
        .select('id')
        .eq('customer_id', customerId)
        .eq('type', 'customer-support')
        .order('created_at', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(res as List);
    if (list.isEmpty) return null;
    final id = list.first['id'] as String?;
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Stream conversations where customer_id = [customerId]. Filter by [type].
  /// Returns list of maps: id, otherParticipantName, lastMessage, lastMessageAt (DateTime?).
  /// Cook chats show chef name from chef_profiles.kitchen_name using chef_id.
  Stream<List<Map<String, dynamic>>> watchConversations(String customerId, String type) {
    return _sb
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .asyncMap((list) async {
          var filtered = list.where((row) => row['type'] == type).toList();
          final chefNames = <String, String>{};
          if (type == 'customer-chef') {
            final chefIds = filtered
                .map((row) => row['chef_id'] as String?)
                .whereType<String>()
                .toSet()
                .toList();
            if (chefIds.isNotEmpty) {
              final res = await _sb
                  .from('chef_profiles')
                  .select('id, kitchen_name')
                  .inFilter('id', chefIds);
              for (final r in res as List) {
                final id = r['id'] as String?;
                if (id != null) {
                  chefNames[id] = r['kitchen_name'] as String? ?? 'Cook';
                }
              }
            }
            // One row per cook (legacy DB may have multiple rows per pair).
            final byChef = <String, Map<String, dynamic>>{};
            for (final row in filtered) {
              final ck = (row['chef_id'] as String?) ?? '';
              if (ck.isEmpty) continue;
              final prev = byChef[ck];
              if (prev == null) {
                byChef[ck] = row;
                continue;
              }
              final tRow = _parseDateTime(row['last_message_at'] ?? row['created_at']);
              final tPrev = _parseDateTime(prev['last_message_at'] ?? prev['created_at']);
              if (tRow != null && (tPrev == null || tRow.isAfter(tPrev))) {
                byChef[ck] = row;
              }
            }
            filtered = byChef.values.toList();
          }
          filtered.sort((a, b) {
            final atA = _parseDateTime(a['last_message_at'] ?? a['created_at']);
            final atB = _parseDateTime(b['last_message_at'] ?? b['created_at']);
            if (atA == null && atB == null) return 0;
            if (atA == null) return 1;
            if (atB == null) return -1;
            return atB.compareTo(atA);
          });
          final convIds = filtered
              .map((row) => (row['id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toList();
          final latestByConv = await _latestMessageByConversationId(convIds);
          final rows = filtered.map((row) {
            final id = (row['id'] ?? '').toString();
            final lm = id.isNotEmpty ? latestByConv[id] : null;
            String? lastMsg = row['last_message'] as String?;
            DateTime? lastAt = _parseDateTime(row['last_message_at'] ?? row['created_at']);
            if (lm != null) {
              lastMsg = lm.content;
              lastAt = lm.at ?? lastAt;
            } else if (lastMsg != null) {
              lastMsg = lastMsg.trim();
              if (lastMsg.isEmpty) lastMsg = null;
            }
            final otherName = _otherParticipantName(row, type, chefNames);
            return {
              'id': row['id'] as String?,
              'otherParticipantName': otherName,
              'lastMessage': lastMsg,
              'lastMessageAt': lastAt,
            };
          }).toList();
          rows.sort((a, b) {
            final atA = a['lastMessageAt'] as DateTime?;
            final atB = b['lastMessageAt'] as DateTime?;
            if (atA == null && atB == null) return 0;
            if (atA == null) return 1;
            if (atB == null) return -1;
            return atB.compareTo(atA);
          });
          return rows;
        });
  }

  String _otherParticipantName(
    Map<String, dynamic> row,
    String type,
    Map<String, String> chefNames,
  ) {
    if (type == 'customer-support' || row['chef_id'] == null) return 'Support Team';
    final chefId = row['chef_id'] as String?;
    if (chefId != null && chefNames.containsKey(chefId)) {
      return chefNames[chefId]!;
    }
    if (row['other_participant_name'] != null && (row['other_participant_name'] as String).isNotEmpty) {
      return row['other_participant_name'] as String;
    }
    return 'Cook';
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Inbox rows often omit [conversations.last_message] (not updated on send); truth is in [messages].
  Future<Map<String, _LatestMsg>> _latestMessageByConversationId(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return {};
    final cap = (conversationIds.length * ChatLimits.recentMessagesForUnread)
        .clamp(ChatLimits.recentMessagesForUnread, ChatLimits.maxInboxBatchMessageRows);
    try {
      final res = await _sb
          .from('messages')
          .select('conversation_id, content, created_at')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false)
          .limit(cap);
      final out = <String, _LatestMsg>{};
      for (final raw in res as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final cid = (m['conversation_id'] ?? '').toString();
        if (cid.isEmpty || out.containsKey(cid)) continue;
        final text = (m['content'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        out[cid] = (content: text, at: _parseDateTime(m['created_at']));
      }
      return out;
    } catch (e, st) {
      debugPrint('[CustomerChat] _latestMessageByConversationId: $e\n$st');
      return {};
    }
  }

  /// Stream messages for a conversation. Returns list of maps: id, senderId, content, createdAt (String).
  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .map((list) {
          final sorted = List<Map<String, dynamic>>.from(list);
          sorted.sort((a, b) {
            final atA = _parseDateTime(a['created_at']);
            final atB = _parseDateTime(b['created_at']);
            if (atA == null && atB == null) return 0;
            if (atA == null) return 1;
            if (atB == null) return -1;
            return atA.compareTo(atB);
          });
          final capped = sorted.length > ChatLimits.maxMessagesPerThread
              ? sorted.sublist(sorted.length - ChatLimits.maxMessagesPerThread)
              : sorted;
          return capped.map((row) {
              final at = row['created_at'];
              final rawSender = row['sender_id'];
              final senderStr = rawSender == null ? '' : rawSender.toString().trim();
              return {
                'id': row['id'] as String?,
                'senderId': senderStr.isEmpty ? null : senderStr,
                'content': row['content'] as String?,
                'createdAt': at is DateTime
                    ? at.toIso8601String()
                    : (at is String ? at : at?.toString()),
              };
            }).toList();
        });
  }

  /// Send a message. Accepts [conversationId] or [chatId].
  /// Also updates [conversations.last_message] when those columns exist and RLS allows (best-effort).
  /// [senderId] is ignored; [sender_id] is the signed-in session user.
  Future<void> sendMessage({
    String? conversationId,
    String? chatId,
    String? senderId,
    required String content,
  }) async {
    final cid = conversationId ?? chatId ?? '';
    if (cid.isEmpty) throw ArgumentError('conversationId or chatId required');
    final trimmed = content.trim();
    if (trimmed.isEmpty) throw ArgumentError('Message content is empty');
    final sid = (supabaseAuthUserId(_sb) ?? '').trim();
    if (sid.isEmpty) {
      throw ArgumentError('Must be signed in to send messages');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _sb.from('messages').insert({
        'conversation_id': cid,
        'sender_id': sid,
        'content': trimmed,
        'is_read': false,
        'created_at': now,
      });
    } catch (e, st) {
      debugPrint('[CustomerChat] sendMessage error: $e');
      debugPrint('[CustomerChat] sendMessage stackTrace: $st');
      rethrow;
    }
    try {
      await _sb.from('conversations').update({
        'last_message': trimmed,
        'last_message_at': now,
      }).eq('id', cid);
    } catch (e, st) {
      debugPrint('[CustomerChat] conversations last_message update (non-fatal): $e\n$st');
    }
  }

  /// Create a customer-chef conversation. Returns conversation id.
  /// Schema: id, type, customer_id, chef_id, admin_id, created_at.
  Future<String> createConversation({
    required String customerId,
    required String chefId,
    required String chefName,
  }) async {
    final cust = customerId.trim();
    final chef = chefId.trim();
    if (cust.isEmpty || chef.isEmpty) {
      throw ArgumentError('customerId and chefId must be non-empty');
    }
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final res = await _sb.from('conversations').insert({
        'customer_id': cust,
        'chef_id': chef,
        'type': 'customer-chef',
        'created_at': now,
      }).select('id').single();
      final id = res['id'] as String?;
      if (id == null || id.isEmpty) throw Exception('Failed to create conversation');
      return id;
    } catch (e, st) {
      debugPrint('[CustomerChat] createConversation error: $e');
      debugPrint('[CustomerChat] createConversation stackTrace: $st');
      rethrow;
    }
  }

  /// Sets [conversations.order_id] on the pair thread so admin “order → chat” works.
  /// No-op if column/RLS missing (run [supabase_conversations_order_id.sql]).
  Future<void> tryLinkCustomerChefConversationToOrder({
    required String conversationId,
    required String orderId,
    required String customerId,
    required String chefId,
  }) async {
    final conv = conversationId.trim();
    final oid = orderId.trim();
    final cust = customerId.trim();
    final chef = chefId.trim();
    if (conv.isEmpty || oid.isEmpty || cust.isEmpty || chef.isEmpty) return;
    try {
      await _sb
          .from('conversations')
          .update({'order_id': oid})
          .eq('id', conv)
          .eq('customer_id', cust)
          .eq('chef_id', chef)
          .eq('type', 'customer-chef');
    } catch (e, st) {
      debugPrint('[CustomerChat] tryLinkCustomerChefConversationToOrder: $e\n$st');
    }
  }

  /// One **customer–chef** thread per pair.
  /// [linkOrderId]: when opening chat from an order, tags the thread for admin monitoring.
  Future<String> getOrCreateCustomerChefChat({
    required String customerId,
    required String chefId,
    required String chefName,
    String? linkOrderId,
  }) async {
    final cust = customerId.trim();
    final chef = chefId.trim();
    if (cust.isEmpty || chef.isEmpty) {
      throw ArgumentError('customerId and chefId must be non-empty');
    }
    try {
      final existingId = await _latestCustomerChefConversationId(
        customerId: cust,
        chefId: chef,
      );
      Future<String> finish(String id) async {
        final lo = linkOrderId?.trim();
        if (lo != null && lo.isNotEmpty) {
          await tryLinkCustomerChefConversationToOrder(
            conversationId: id,
            orderId: lo,
            customerId: cust,
            chefId: chef,
          );
        }
        return id;
      }

      if (existingId != null) return finish(existingId);
      try {
        final created = await createConversation(
          customerId: cust,
          chefId: chef,
          chefName: chefName,
        );
        return finish(created);
      } on PostgrestException catch (pe) {
        if (pe.code == '23505') {
          final again = await _latestCustomerChefConversationId(
            customerId: cust,
            chefId: chef,
          );
          if (again != null) return finish(again);
        }
        rethrow;
      }
    } catch (e, st) {
      debugPrint('[CustomerChat] getOrCreateCustomerChefChat error: $e');
      debugPrint('[CustomerChat] getOrCreateCustomerChefChat stackTrace: $st');
      rethrow;
    }
  }

  /// Get or create customer-support conversation.
  Future<String> getOrCreateCustomerSupportChat({
    required String customerId,
  }) async {
    final cid = customerId.trim();
    if (cid.isEmpty) throw ArgumentError('customerId required');
    try {
      final existingId = await _latestCustomerSupportConversationId(cid);
      if (existingId != null) return existingId;
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        final res = await _sb.from('conversations').insert({
          'customer_id': cid,
          'chef_id': null,
          'type': 'customer-support',
          'created_at': now,
        }).select('id').single();
        final id = res['id'] as String?;
        if (id == null || id.isEmpty) throw Exception('Failed to create support conversation');
        return id;
      } on PostgrestException catch (pe) {
        if (pe.code == '23505') {
          final again = await _latestCustomerSupportConversationId(cid);
          if (again != null) return again;
        }
        rethrow;
      }
    } catch (e, st) {
      debugPrint('[CustomerChat] getOrCreateCustomerSupportChat error: $e');
      debugPrint('[CustomerChat] getOrCreateCustomerSupportChat stackTrace: $st');
      rethrow;
    }
  }
}
