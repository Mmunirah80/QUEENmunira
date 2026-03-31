import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/widgets/press_scale.dart';

class NahamCustomerChatScreen extends ConsumerStatefulWidget {
  const NahamCustomerChatScreen({super.key});

  @override
  ConsumerState<NahamCustomerChatScreen> createState() => _NahamCustomerChatScreenState();
}

class _NahamCustomerChatScreenState extends ConsumerState<NahamCustomerChatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        title: const Text('Chat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.white24,
              highlightColor: Colors.white12,
              tabBarTheme: const TabBarThemeData(
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xE6FFFFFF),
                indicatorColor: Colors.white,
                dividerColor: Colors.transparent,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
              indicatorColor: Colors.white,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Cook Chat'),
                Tab(text: 'Support'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ConversationList(type: 'customer-chef'),
          _ConversationList(type: 'customer-support'),
        ],
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  final String type;

  const _ConversationList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = type == 'customer-chef'
        ? ref.watch(customerChefChatsStreamProvider)
        : ref.watch(customerSupportChatsStreamProvider);
    return stream.when(
      data: (chats) {
        if (chats.isEmpty) {
          return Center(
            child: Text(
              type == 'customer-chef'
                  ? 'No cook conversations yet'
                  : 'No support conversations yet',
              style: const TextStyle(color: AppDesignSystem.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          itemBuilder: (_, i) {
            final chat = chats[i];
            final id = chat['id'] as String?;
            if (id == null || id.isEmpty) return const SizedBox.shrink();
            final name = chat['otherParticipantName'] as String? ?? '—';
            final last = chat['lastMessage'] as String? ?? '';
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  last.isEmpty ? 'No messages yet' : last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NahamCustomerChatConversationScreen(
                      chatId: id,
                      name: name,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userFriendlyErrorMessage(e),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppDesignSystem.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.invalidate(customerChefChatsStreamProvider);
                  ref.invalidate(customerSupportChatsStreamProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PendingStatus { sending, failed }

class _PendingMessage {
  final String id;
  final String text;
  final DateTime createdAt;
  final _PendingStatus status;

  const _PendingMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.status,
  });

  _PendingMessage copyWith({_PendingStatus? status}) {
    return _PendingMessage(
      id: id,
      text: text,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}

class NahamCustomerChatConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String name;

  const NahamCustomerChatConversationScreen({
    super.key,
    required this.chatId,
    required this.name,
  });

  @override
  ConsumerState<NahamCustomerChatConversationScreen> createState() =>
      _NahamCustomerChatConversationScreenState();
}

class _NahamCustomerChatConversationScreenState extends ConsumerState<NahamCustomerChatConversationScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_PendingMessage> _pending = <_PendingMessage>[];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = ref.read(customerIdProvider);
    if (uid.isEmpty) return;

    final localId = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _sending = true;
      _pending.add(
        _PendingMessage(
          id: localId,
          text: text,
          createdAt: DateTime.now(),
          status: _PendingStatus.sending,
        ),
      );
      _ctrl.clear();
    });

    try {
      await ref.read(customerChatSupabaseDataSourceProvider).sendMessage(
            conversationId: widget.chatId,
            senderId: uid,
            content: text,
          );
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((m) => m.id == localId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _pending.indexWhere((m) => m.id == localId);
        if (i >= 0) _pending[i] = _pending[i].copyWith(status: _PendingStatus.failed);
      });
      SnackbarHelper.error(
        context,
        userFriendlyErrorMessage(e, fallback: 'Failed to send message.'),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retryPending(String localId) async {
    final uid = ref.read(customerIdProvider);
    if (uid.isEmpty) return;
    final i = _pending.indexWhere((m) => m.id == localId);
    if (i < 0) return;
    final msg = _pending[i];
    setState(() => _pending[i] = msg.copyWith(status: _PendingStatus.sending));
    try {
      await ref.read(customerChatSupabaseDataSourceProvider).sendMessage(
            conversationId: widget.chatId,
            senderId: uid,
            content: msg.text,
          );
      if (!mounted) return;
      setState(() => _pending.removeWhere((m) => m.id == localId));
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending[i] = _pending[i].copyWith(status: _PendingStatus.failed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(customerIdProvider);
    final messagesAsync = ref.watch(customerChatMessagesStreamProvider(widget.chatId));

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        title: Text(widget.name),
      ),
      body: Column(
        children: [
          if (_pending.any((m) => m.status == _PendingStatus.failed))
            Container(
              width: double.infinity,
              color: Colors.orange.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(
                'Some messages failed. Tap retry on failed bubbles.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final items = <Widget>[];
                for (final m in messages) {
                  final isMe = (m['senderId'] as String? ?? '') == uid;
                  items.add(
                    _MessageBubble(
                      text: m['content'] as String? ?? '',
                      isMe: isMe,
                      timeLabel: _formatTime(m['createdAt']),
                    ),
                  );
                }
                for (final p in _pending) {
                  items.add(
                    _MessageBubble(
                      text: p.text,
                      isMe: true,
                      timeLabel: _time(p.createdAt),
                      pendingStatus: p.status,
                      onRetry: p.status == _PendingStatus.failed
                          ? () => _retryPending(p.id)
                          : null,
                    ),
                  );
                }

                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation.',
                      style: TextStyle(color: AppDesignSystem.textSecondary),
                    ),
                  );
                }
                return ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: items,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  userFriendlyErrorMessage(e),
                  style: const TextStyle(color: AppDesignSystem.textSecondary),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppDesignSystem.backgroundOffWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: PressScale(
                    enabled: !_sending,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppDesignSystem.primary,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(dynamic at) {
    if (at is String) {
      final d = DateTime.tryParse(at);
      if (d != null) return _time(d);
    }
    return '—';
  }

  static String _time(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String timeLabel;
  final _PendingStatus? pendingStatus;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.timeLabel,
    this.pendingStatus,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? AppDesignSystem.primary : Colors.white;
    final fg = isMe ? Colors.white : AppDesignSystem.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(text, style: TextStyle(color: fg)),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeLabel, style: const TextStyle(fontSize: 11, color: AppDesignSystem.textSecondary)),
                    if (pendingStatus == _PendingStatus.sending) ...[
                      const SizedBox(width: 6),
                      const Text('sending...', style: TextStyle(fontSize: 11, color: AppDesignSystem.textSecondary)),
                    ],
                    if (pendingStatus == _PendingStatus.failed) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onRetry,
                        child: const Text(
                          'failed - retry',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

