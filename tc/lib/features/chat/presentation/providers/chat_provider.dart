import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../data/chat_limits.dart';
import '../../data/datasources/chat_mock_datasource.dart';
import '../../data/datasources/cook_chat_supabase_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/repositories/chat_repository.dart';

bool _chefCookSessionForChat(UserEntity? user, AppRole? selectedLoginRole) {
  if (user == null || user.id.isEmpty) return false;
  if (user.isChef) return true;
  return selectedLoginRole == AppRole.chef;
}

/// Shared in-memory chat when cook runs with mock orders (no Supabase profiles FK).
final _cookMockOrdersChatDataSource = ChatMockDataSource();

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (ref.watch(cookOrdersUsingMockProvider)) {
    return ChatRepositoryImpl(remoteDataSource: _cookMockOrdersChatDataSource);
  }
  final user = ref.watch(authStateProvider).valueOrNull;
  final selectedLoginRole = ref.watch(selectedRoleProvider);
  final chefId = (user != null && _chefCookSessionForChat(user, selectedLoginRole))
      ? user.id
      : '';
  final dataSource = CookChatSupabaseDataSource(chefId: chefId);
  return ChatRepositoryImpl(remoteDataSource: dataSource);
});

final chatsProvider = FutureProvider<List<ChatEntity>>((ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getChats();
});

DateTime _parseDateTime(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

/// One inbox row per customer when legacy rows duplicated (customer-chef) threads.
List<ChatEntity> _dedupeChatsOnePerCustomer(List<ChatEntity> chats) {
  final bestByCustomer = <String, ChatEntity>{};
  final unreadSum = <String, int>{};
  for (final c in chats) {
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
    return ChatEntity(
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

final chatsStreamProvider = StreamProvider<List<ChatEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final chefId = user?.id ?? '';
  if (chefId.isEmpty) return const Stream<List<ChatEntity>>.empty();

  return Supabase.instance.client
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((rows) async {
    final scopedRows = rows.where((row) {
      final rowChefId = (row['chef_id'] ?? '').toString();
      final rowType = (row['type'] ?? '').toString();
      return rowChefId == chefId && rowType == 'customer-chef';
    }).toList();

    final chats = <ChatEntity>[];
    final conversationIds = scopedRows
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final lastMessageByConversation = <String, Map<String, dynamic>>{};
    final unreadByConversation = <String, int>{};
    if (conversationIds.isNotEmpty) {
      final cap = (conversationIds.length * ChatLimits.recentMessagesForUnread)
          .clamp(ChatLimits.recentMessagesForUnread, ChatLimits.maxInboxBatchMessageRows);
      final msgRows = await Supabase.instance.client
          .from('messages')
          .select('conversation_id,sender_id,content,created_at,is_read')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false)
          .limit(cap);

      final recentByConv = <String, List<Map<String, dynamic>>>{};
      for (final raw in (msgRows as List)) {
        final m = raw as Map<String, dynamic>;
        final conversationId = (m['conversation_id'] ?? '').toString();
        if (conversationId.isEmpty) continue;
        lastMessageByConversation.putIfAbsent(conversationId, () => m);
        final bucket = recentByConv.putIfAbsent(conversationId, () => []);
        if (bucket.length < ChatLimits.recentMessagesForUnread) {
          bucket.add(m);
        }
      }
      for (final entry in recentByConv.entries) {
        var n = 0;
        for (final m in entry.value) {
          final senderId = (m['sender_id'] ?? '').toString();
          final isRead = m['is_read'] as bool? ?? false;
          if (senderId != chefId && !isRead) n++;
        }
        unreadByConversation[entry.key] = n;
      }
    }

    for (final row in scopedRows) {
      final conversationId = (row['id'] ?? '').toString();
      if (conversationId.isEmpty) continue;
      final customerId = (row['customer_id'] ?? '').toString();
      final createdAt = _parseDateTime(row['created_at']);
      var lastMessage = 'New conversation';
      var lastTime = createdAt;
      final latest = lastMessageByConversation[conversationId];
      if (latest != null) {
        final content = (latest['content'] ?? '').toString();
        if (content.trim().isNotEmpty) {
          lastMessage = content;
        }
        lastTime = _parseDateTime(latest['created_at']);
      }

      chats.add(ChatEntity(
        id: conversationId,
        userId: customerId,
        userName: 'Customer',
        orderId: null,
        lastMessage: lastMessage,
        lastMessageTime: lastTime,
        unreadCount: unreadByConversation[conversationId] ?? 0,
      ));
    }
    chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return _dedupeChatsOnePerCustomer(chats);
  });
});

/// Admin ↔ chef support threads ([type] = chef-admin, chef is both participants in DB).
final chefAdminSupportChatsStreamProvider =
    StreamProvider<List<ChatEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final chefId = user?.id ?? '';
  if (chefId.isEmpty) return const Stream<List<ChatEntity>>.empty();

  return Supabase.instance.client
      .from('conversations')
      .stream(primaryKey: ['id'])
      .asyncMap((rows) async {
    final scopedRows = rows.where((row) {
      final rowChefId = (row['chef_id'] ?? '').toString();
      final rowType = (row['type'] ?? '').toString();
      return rowChefId == chefId && rowType == 'chef-admin';
    }).toList();

    final chats = <ChatEntity>[];
    final conversationIds = scopedRows
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final lastMessageByConversation = <String, Map<String, dynamic>>{};
    final unreadByConversation = <String, int>{};
    if (conversationIds.isNotEmpty) {
      final msgRows = await Supabase.instance.client
          .from('messages')
          .select('conversation_id,sender_id,content,created_at,is_read')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false);

      for (final raw in (msgRows as List)) {
        final m = raw as Map<String, dynamic>;
        final conversationId = (m['conversation_id'] ?? '').toString();
        if (conversationId.isEmpty) continue;

        lastMessageByConversation.putIfAbsent(conversationId, () => m);

        final senderId = (m['sender_id'] ?? '').toString();
        final isRead = m['is_read'] as bool? ?? false;
        if (senderId != chefId && !isRead) {
          unreadByConversation[conversationId] =
              (unreadByConversation[conversationId] ?? 0) + 1;
        }
      }
    }

    for (final row in scopedRows) {
      final conversationId = (row['id'] ?? '').toString();
      if (conversationId.isEmpty) continue;
      final createdAt = _parseDateTime(row['created_at']);
      var lastMessage = 'Messages from the Naham team';
      var lastTime = createdAt;
      final latest = lastMessageByConversation[conversationId];
      if (latest != null) {
        final content = (latest['content'] ?? '').toString();
        if (content.trim().isNotEmpty) {
          lastMessage = content;
        }
        lastTime = _parseDateTime(latest['created_at']);
      }

      chats.add(ChatEntity(
        id: conversationId,
        userId: chefId,
        userName: 'Naham Support',
        lastMessage: lastMessage,
        lastMessageTime: lastTime,
        unreadCount: unreadByConversation[conversationId] ?? 0,
      ));
    }
    chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return chats;
  });
});

final messagesProvider = FutureProvider.family<List<MessageEntity>, String>((ref, chatId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getMessages(chatId);
});

final messagesStreamProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, chatId) {
  if (chatId.isEmpty) return const Stream<List<MessageEntity>>.empty();
  return Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', chatId)
      .order('created_at')
      .map((rows) {
        final items = rows.map((row) {
          final createdAtRaw = row['created_at'];
          final createdAt = createdAtRaw is String
              ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
              : createdAtRaw is DateTime
                  ? createdAtRaw
                  : DateTime.now();
          return MessageEntity(
            id: (row['id'] ?? '').toString(),
            chatId: (row['conversation_id'] ?? chatId).toString(),
            senderId: (row['sender_id'] ?? '').toString(),
            content: (row['content'] ?? '').toString(),
            timestamp: createdAt,
            isRead: row['is_read'] as bool? ?? false,
          );
        }).toList();
        items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (items.length > ChatLimits.maxMessagesPerThread) {
          return items.sublist(items.length - ChatLimits.maxMessagesPerThread);
        }
        return items;
      });
});
