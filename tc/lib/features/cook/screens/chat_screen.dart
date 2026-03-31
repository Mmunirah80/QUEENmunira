// ============================================================
// COOK CHAT — RTL, TC theme. Data from chat provider (Supabase-backed).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/naham_empty_screens.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../../../features/orders/presentation/providers/orders_provider.dart';
import '../../chat/domain/entities/chat_entity.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const primaryDark = AppDesignSystem.primaryDark;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

// ══════════════════════════════════════════════════════════════
// CHAT SCREEN (list) — exact Customer layout
// ══════════════════════════════════════════════════════════════
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static String _formatTime(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return DateFormat.jm().format(d);
    }
    if (now.difference(d).inDays == 1) return 'Yesterday';
    return DateFormat.Md().format(d);
  }

  Future<Map<String, String>> _loadCustomerNames(List<ChatEntity> chats) async {
    final ids = chats.map((c) => c.userId).where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id,full_name')
          .inFilter('id', ids);
      final map = <String, String>{};
      for (final row in (rows as List)) {
        final m = row as Map<String, dynamic>;
        final id = (m['id'] ?? '').toString();
        final name = (m['full_name'] ?? '').toString().trim();
        if (id.isNotEmpty && name.isNotEmpty) {
          map[id] = name;
        }
      }
      return map;
    } catch (e) {
      debugPrint('[CookChat] load customer names error=$e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerChatsAsync = ref.watch(chatsStreamProvider);
    final supportChatsAsync = ref.watch(chefAdminSupportChatsStreamProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        body: Column(
          children: [
            _buildHeader(context),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: _NC.primaryDark,
                labelColor: _NC.primaryDark,
                unselectedLabelColor: _NC.textSub,
                tabs: const [
                  Tab(text: 'Customers'),
                  Tab(text: 'Support'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatList(context, customerChatsAsync, isSupport: false),
                  _buildChatList(context, supportChatsAsync, isSupport: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(
    BuildContext context,
    AsyncValue<List<ChatEntity>> chatsAsync, {
    required bool isSupport,
  }) {
    return chatsAsync.when(
      data: (chats) {
        final filtered = chats;

        if (isSupport) {
          if (filtered.isEmpty) {
            return const Center(
              child: EmptyChatContent(
                title: 'No messages from the team yet',
                subtitle:
                    'When an admin reviews your documents, updates will appear here. You will also get notifications.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(chefAdminSupportChatsStreamProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final chat = filtered[index];
                final name = chat.userName;
                final last = chat.lastMessage;
                final time = _formatTime(chat.lastMessageTime);
                final unread = chat.unreadCount.toString();
                final hasUnread = chat.unreadCount > 0;
                final typeLabel = isSupport
                    ? 'Support'
                    : ((chat.orderId != null && chat.orderId!.isNotEmpty)
                        ? 'Order thread'
                        : 'Customer');
                final typeBg =
                    isSupport ? Colors.blue.shade50 : Colors.green.shade50;
                final typeColor =
                    isSupport ? Colors.blue.shade700 : Colors.green.shade700;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _NC.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CookChatConversationScreen(
                          name: name,
                          chatId: chat.id,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _NC.primaryLight.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSupport
                                ? Icons.support_agent_rounded
                                : Icons.person_rounded,
                            color: _NC.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: typeBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      typeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: typeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (chat.orderId != null &&
                                  chat.orderId!.isNotEmpty)
                                Text(
                                  chat.orderId!.length > 8
                                      ? 'Order ${chat.orderId!.substring(0, 8)}…'
                                      : 'Order ${chat.orderId!}',
                                  style: TextStyle(
                                    color: _NC.primaryDark
                                        .withValues(alpha: 0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (chat.orderId != null &&
                                  chat.orderId!.isNotEmpty)
                                const SizedBox(height: 2),
                              Text(
                                last,
                                style: const TextStyle(
                                  color: _NC.textSub,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              time,
                              style: const TextStyle(
                                color: _NC.textSub,
                                fontSize: 11,
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: _NC.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unread,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }

        if (filtered.isEmpty) {
          return const Center(
            child: EmptyChatContent(
              subtitle:
                  'When customers message you, conversations will appear here.',
            ),
          );
        }

        return FutureBuilder<Map<String, String>>(
          future: _loadCustomerNames(filtered),
          builder: (context, snapshot) {
            final names = snapshot.data ?? const <String, String>{};
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(chatsStreamProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final chat = filtered[index];
                  final name = names[chat.userId] ?? chat.userName;
                  final last = chat.lastMessage;
                  final time = _formatTime(chat.lastMessageTime);
                  final unread = chat.unreadCount.toString();
                  final hasUnread = chat.unreadCount > 0;
                  const typeLabel = 'Customer';
                  final typeBg = Colors.green.shade50;
                  final typeColor = Colors.green.shade700;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _NC.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CookChatConversationScreen(
                            name: name,
                            chatId: chat.id,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _NC.primaryLight.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: _NC.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeBg,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        (chat.orderId != null &&
                                                chat.orderId!.isNotEmpty)
                                            ? 'Order thread'
                                            : typeLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: typeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (chat.orderId != null &&
                                    chat.orderId!.isNotEmpty)
                                  Text(
                                    chat.orderId!.length > 8
                                        ? 'Order ${chat.orderId!.substring(0, 8)}…'
                                        : 'Order ${chat.orderId!}',
                                    style: TextStyle(
                                      color: _NC.primaryDark
                                          .withValues(alpha: 0.85),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (chat.orderId != null &&
                                    chat.orderId!.isNotEmpty)
                                  const SizedBox(height: 2),
                                Text(
                                  last,
                                  style: const TextStyle(
                                    color: _NC.textSub,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                time,
                                style: const TextStyle(
                                  color: _NC.textSub,
                                  fontSize: 11,
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: _NC.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unread,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (err, _) => Center(
        child: ErrorStateContent(
          message: userFriendlyErrorMessage(err),
          onRetry: () => isSupport
              ? ref.invalidate(chefAdminSupportChatsStreamProvider)
              : ref.invalidate(chatsStreamProvider),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _NC.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  AppDesignSystem.logoAsset,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'N',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Center(
                  child: Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Conversation (detail) — RTL, TC theme, messages from provider ─────
class CookChatConversationScreen extends ConsumerStatefulWidget {
  final String name;
  final String chatId;
  final String? orderId;

  const CookChatConversationScreen({
    super.key,
    required this.name,
    required this.chatId,
    this.orderId,
  });

  @override
  ConsumerState<CookChatConversationScreen> createState() => _CookChatConversationScreenState();
}

class _CookChatConversationScreenState extends ConsumerState<CookChatConversationScreen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatRepositoryProvider).markAsRead(widget.chatId).catchError((Object e) {
        debugPrint('[CookChat] markAsRead error=$e');
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final content = _ctrl.text.trim();
    if (content.isEmpty) return;
    _ctrl.clear();
    ref.read(chatRepositoryProvider).sendMessage(widget.chatId, content).then((_) {
      if (mounted) ref.invalidate(chatsProvider);
    }).catchError((Object e) {
      debugPrint('[CookChat] send message error=$e');
      if (mounted) {
        _ctrl.text = content;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final useMockChat = ref.watch(cookOrdersUsingMockProvider);
    final messagesAsync = useMockChat
        ? ref.watch(messagesProvider(widget.chatId))
        : ref.watch(messagesStreamProvider(widget.chatId));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id ?? '';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        appBar: AppBar(
          backgroundColor: _NC.primary,
          foregroundColor: Colors.white,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.name),
              if (widget.orderId != null && widget.orderId!.isNotEmpty)
                Text(
                  'Order ${widget.orderId}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        ),
        body: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages yet', style: TextStyle(color: _NC.textSub)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == currentUserId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onLongPress: isMe && !useMockChat
                              ? () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete message'),
                                      content: const Text('Delete this message?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    try {
                                      await Supabase.instance.client
                                          .from('messages')
                                          .delete()
                                          .eq('id', msg.id);
                                      if (mounted) {
                                        ref.invalidate(messagesProvider(widget.chatId));
                                        ref.invalidate(
                                          messagesStreamProvider(widget.chatId),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(userFriendlyErrorMessage(e))),
                                        );
                                      }
                                    }
                                  }
                                }
                              : null,
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe ? _NC.primary : _NC.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                                      bottomRight: Radius.circular(isMe ? 4 : 18),
                                    ),
                                  ),
                                  child: Text(
                                    msg.content,
                                    style: TextStyle(fontSize: 14, color: isMe ? Colors.white : _NC.text),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: LoadingWidget()),
                error: (e, _) => Center(
                  child: ErrorStateContent(
                    message: userFriendlyErrorMessage(e),
                    onRetry: () {
                      if (useMockChat) {
                        ref.invalidate(messagesProvider(widget.chatId));
                      } else {
                        ref.invalidate(messagesStreamProvider(widget.chatId));
                      }
                    },
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              color: _NC.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: _NC.textSub, fontSize: 14),
                        filled: true,
                        fillColor: _NC.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: _NC.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
