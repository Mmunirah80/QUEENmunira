import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_auth_user_id.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../chat_limits.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'chat_remote_datasource.dart';

/// Supabase cook-side chat: one **customer–chef** row per pair; inbox uses batched message queries (no N+1).
///
/// Tables: `conversations`, `messages`.
class CookChatSupabaseDataSource implements ChatRemoteDataSource {
  final SupabaseClient _client;

  SupabaseQueryBuilder get _conversations => _client.from('conversations');
  SupabaseQueryBuilder get _messages => _client.from('messages');

  final String chefId;

  CookChatSupabaseDataSource({
    SupabaseClient? client,
    required this.chefId,
  }) : _client = client ?? SupabaseConfig.dataClient;

  /// Authenticated user id for this cook (matches [messages.sender_id]).
  String get _selfId => (supabaseAuthUserId(_client) ?? chefId).trim();

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  Future<List<ChatModel>> getChats() async {
    if (chefId.isEmpty) return [];
    debugPrint('[CookChat] getChats chefId=$chefId');
    List<dynamic> list;
    try {
      final rows = await _conversations
          .select('id, customer_id, created_at')
          .eq('chef_id', chefId)
          .eq('type', 'customer-chef');
      list = rows as List<dynamic>? ?? const [];
    } on PostgrestException catch (e) {
      debugPrint('[CookChat] getChats conversations: $e');
      rethrow;
    }

    final convRows = list.map((raw) => raw as Map<String, dynamic>).toList();
    final convIds = convRows
        .map((r) => r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final latestByConv = <String, Map<String, dynamic>>{};
    final recentByConv = <String, List<Map<String, dynamic>>>{};

    if (convIds.isNotEmpty) {
      final cap = (convIds.length * ChatLimits.recentMessagesForUnread)
          .clamp(ChatLimits.recentMessagesForUnread, ChatLimits.maxInboxBatchMessageRows);
      try {
        final msgRows = await _messages
            .select('id, sender_id, content, created_at, is_read, conversation_id')
            .inFilter('conversation_id', convIds)
            .order('created_at', ascending: false)
            .limit(cap);

        for (final raw in (msgRows as List? ?? const [])) {
          final m = raw as Map<String, dynamic>;
          final cid = (m['conversation_id'] ?? '').toString();
          if (cid.isEmpty) continue;
          latestByConv.putIfAbsent(cid, () => m);
          final bucket = recentByConv.putIfAbsent(cid, () => []);
          if (bucket.length < ChatLimits.recentMessagesForUnread) {
            bucket.add(m);
          }
        }
      } on PostgrestException catch (e) {
        debugPrint('[CookChat] getChats batch messages (non-fatal): $e');
      }
    }

    final result = <ChatModel>[];
    for (final row in convRows) {
      final conversationId = row['id'] as String?;
      if (conversationId == null || conversationId.isEmpty) continue;

      final customerId = row['customer_id']?.toString() ?? '';
      final createdAt = _parseDateTime(row['created_at']) ?? DateTime.now();

      final latest = latestByConv[conversationId];
      var lastMessage = '';
      var lastAt = createdAt;
      if (latest != null) {
        lastMessage = (latest['content'] as String?) ?? '';
        lastAt = _parseDateTime(latest['created_at']) ?? createdAt;
      }

      var unreadCount = 0;
      for (final m in recentByConv[conversationId] ?? const []) {
        final senderId = (m['sender_id'] ?? '').toString();
        final isRead = m['is_read'] as bool? ?? false;
        if (senderId != _selfId && !isRead) unreadCount++;
      }

      result.add(
        ChatModel(
          id: conversationId,
          userId: customerId,
          userName: 'Customer',
          orderId: null,
          lastMessage: lastMessage.isEmpty ? 'New conversation' : lastMessage,
          lastMessageTime: lastAt,
          unreadCount: unreadCount,
        ),
      );
    }

    result.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return _dedupeChatsByCustomer(result);
  }

  List<ChatModel> _dedupeChatsByCustomer(List<ChatModel> list) {
    final bestByCustomer = <String, ChatModel>{};
    final unreadSum = <String, int>{};
    for (final c in list) {
      final k = c.userId;
      if (k.isEmpty) continue;
      unreadSum[k] = (unreadSum[k] ?? 0) + c.unreadCount;
      final prev = bestByCustomer[k];
      if (prev == null || c.lastMessageTime.isAfter(prev.lastMessageTime)) {
        bestByCustomer[k] = c;
      }
    }
    final out = bestByCustomer.entries.map((e) {
      final c = e.value;
      return ChatModel(
        id: c.id,
        userId: c.userId,
        userName: c.userName,
        userImageUrl: c.userImageUrl,
        orderId: null,
        lastMessage: c.lastMessage,
        lastMessageTime: c.lastMessageTime,
        unreadCount: unreadSum[e.key] ?? c.unreadCount,
      );
    }).toList();
    out.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return out;
  }

  @override
  Future<List<MessageModel>> getMessages(String chatId) async {
    if (chatId.isEmpty) return [];
    debugPrint('[CookChat] getMessages chatId=$chatId chefId=$chefId');
    final rows = await _messages
        .select('id, conversation_id, sender_id, content, is_read, created_at')
        .eq('conversation_id', chatId)
        .order('created_at', ascending: false)
        .limit(ChatLimits.maxMessagesPerThread);

    final list = rows as List<dynamic>? ?? const [];
    final messages = list.map((raw) {
      final row = raw as Map<String, dynamic>;
      final createdAt = _parseDateTime(row['created_at']) ?? DateTime.now();
      return MessageModel(
        id: (row['id'] ?? '').toString(),
        chatId: chatId,
        senderId: (row['sender_id'] ?? '').toString(),
        content: (row['content'] ?? '').toString(),
        timestamp: createdAt,
        isRead: row['is_read'] as bool? ?? false,
      );
    }).toList();

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  @override
  Future<void> sendMessage(String chatId, String content) async {
    final trimmed = content.trim();
    final sid = _selfId;
    if (chatId.isEmpty || chefId.isEmpty || sid.isEmpty || trimmed.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    debugPrint('[CookChat] sendMessage chatId=$chatId senderId=$sid');
    await _messages.insert({
      'conversation_id': chatId,
      'sender_id': sid,
      'content': trimmed,
      'is_read': false,
      'created_at': now,
    });
  }

  @override
  Future<void> markAsRead(String chatId) async {
    if (chatId.isEmpty || chefId.isEmpty) return;
    debugPrint('[CookChat] markAsRead chatId=$chatId chefId=$chefId');
    await _messages
        .update({'is_read': true})
        .eq('conversation_id', chatId)
        .neq('sender_id', _selfId);
  }

  Future<String> _existingThreadId(String customerId) async {
    final rows = await _conversations
        .select('id')
        .eq('chef_id', chefId)
        .eq('customer_id', customerId)
        .eq('type', 'customer-chef')
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>? ?? const [];
    if (list.isEmpty) return '';
    final id = (list.first as Map<String, dynamic>)['id']?.toString();
    return (id == null || id.isEmpty) ? '' : id;
  }

  @override
  Future<String> getOrCreateConversation(String customerId) async {
    final cid = customerId.trim();
    if (chefId.isEmpty || cid.isEmpty) {
      throw ArgumentError('Missing chef or customer id');
    }

    final existing = await _existingThreadId(cid);
    if (existing.isNotEmpty) return existing;

    final now = DateTime.now().toUtc().toIso8601String();
    debugPrint('[CookChat] creating conversation chefId=$chefId customerId=$cid');
    try {
      final res = await _conversations
          .insert({
            'chef_id': chefId,
            'customer_id': cid,
            'type': 'customer-chef',
            'created_at': now,
          })
          .select('id')
          .single();
      final id = res['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Failed to create conversation');
      }
      return id;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final again = await _existingThreadId(cid);
        if (again.isNotEmpty) return again;
      }
      rethrow;
    }
  }
}
