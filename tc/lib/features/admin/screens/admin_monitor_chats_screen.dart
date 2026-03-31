import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/orders/presentation/orders_failure.dart';
import '../../chat/domain/entities/chat_entity.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../presentation/providers/admin_monitor_chats_provider.dart';
import '../presentation/providers/admin_providers.dart';

const String kSupportAdminUserId = 'a3291c54-3ee6-4d61-8aea-62d3ff5c5657';

/// Admin: browse all customer–chef threads (monitor / join). Requires RLS admin policies + optional [messages_insert_admin].
class AdminMonitorChatsScreen extends ConsumerWidget {
  const AdminMonitorChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access required')),
      );
    }

    final async = ref.watch(adminCustomerChefChatsStreamProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        title: const Text('Order chats (monitor)'),
      ),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No customer–chef conversations yet.',
                style: TextStyle(color: AppDesignSystem.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = items[i];
              final title = row['title'] as String? ?? 'Chat';
              final last = row['lastMessage'] as String? ?? '';
              final at = row['lastMessageAt'] as DateTime? ?? DateTime.now();
              final orderId = row['orderId'] as String?;
              return Material(
                color: AppDesignSystem.cardWhite,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (orderId != null && orderId.isNotEmpty) 'Order ${orderId.length > 8 ? orderId.substring(0, 8) : orderId}…',
                      last,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Text(
                    DateFormat.MMMd().add_jm().format(at.toLocal()),
                    style: const TextStyle(fontSize: 11, color: AppDesignSystem.textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminMonitorConversationScreen(
                          chatId: row['id'] as String,
                          title: title,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(resolveOrdersUiError(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.invalidate(adminCustomerChefChatsStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminMonitorConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String title;

  const AdminMonitorConversationScreen({
    super.key,
    required this.chatId,
    required this.title,
  });

  @override
  ConsumerState<AdminMonitorConversationScreen> createState() =>
      _AdminMonitorConversationScreenState();
}

class _AdminMonitorConversationScreenState extends ConsumerState<AdminMonitorConversationScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(authStateProvider).valueOrNull?.id ?? '';
    if (uid.isEmpty) return;
    if (uid != kSupportAdminUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed-in user is not the configured support admin account.'),
          ),
        );
      }
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.chatId,
        'sender_id': kSupportAdminUserId,
        'content': text,
        'is_read': false,
        'created_at': now,
      });
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminId = ref.watch(authStateProvider).valueOrNull?.id ?? '';
    final messagesAsync = ref.watch(messagesStreamProvider(widget.chatId));

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (List<MessageEntity> messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: AppDesignSystem.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == adminId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMe ? AppDesignSystem.primary : AppDesignSystem.cardWhite,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                msg.content,
                                style: TextStyle(
                                  color: isMe ? Colors.white : AppDesignSystem.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(resolveOrdersUiError(e), textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => ref.invalidate(messagesStreamProvider(widget.chatId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.paddingOf(context).bottom + 8),
            color: AppDesignSystem.cardWhite,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: 'Message as admin…',
                      filled: true,
                      fillColor: AppDesignSystem.backgroundOffWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
