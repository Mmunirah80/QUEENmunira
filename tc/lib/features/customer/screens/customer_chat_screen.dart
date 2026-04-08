import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/core/widgets/naham_empty_screens.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:naham_cook_app/features/chat/presentation/chat_composer_policy.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_design_tokens.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_thread_row.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_read_only_banner.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/naham_chat_input_bar.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';

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
                      conversationType: type,
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
        child: ErrorStateContent(
          message: userFriendlyErrorMessage(e),
          actionLabel: 'Refresh',
          onRetry: () {
            ref.invalidate(customerChefChatsStreamProvider);
            ref.invalidate(customerSupportChatsStreamProvider);
          },
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
  /// `customer-chef` | `customer-support`
  final String conversationType;

  const NahamCustomerChatConversationScreen({
    super.key,
    required this.chatId,
    required this.name,
    this.conversationType = 'customer-chef',
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
    if (!ChatComposerPolicy.showComposer(
      accountMessagingBlocked: ref.read(authStateProvider).valueOrNull?.isBlocked == true,
    )) {
      return;
    }
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

  static DateTime? _parseMsgCreatedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return DateTime.tryParse(raw.toString());
  }

  /// How many "sending" pendings with the same text precede or equal [p] in FIFO order.
  int _ordinalAmongSendingSameText(_PendingMessage p) {
    final same = _pending
        .where((x) => x.status == _PendingStatus.sending && x.text == p.text)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final idx = same.indexOf(p);
    return idx < 0 ? 0 : idx;
  }

  /// True when the realtime stream already reflects this pending send (avoids duplicate bubbles).
  bool _pendingIsEchoedByStream(
    List<Map<String, dynamic>> messages,
    String uidTrim,
    _PendingMessage p,
  ) {
    if (p.status != _PendingStatus.sending) return false;
    final ord = _ordinalAmongSendingSameText(p);
    var n = 0;
    for (final m in messages) {
      final sid = (m['senderId'] as String? ?? '').trim();
      if (sid != uidTrim) continue;
      final content = (m['content'] as String? ?? '').trim();
      if (content != p.text) continue;
      final at = _parseMsgCreatedAt(m['createdAt']);
      if (at == null) {
        n++;
        continue;
      }
      if (at.isBefore(p.createdAt.subtract(const Duration(seconds: 5)))) continue;
      n++;
    }
    return n > ord;
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(customerIdProvider);
    final uidTrim = uid.trim();
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final customerName = authUser?.name.trim() ?? '';
    final accountBlocked = authUser?.isBlocked == true;
    final showComposer = ChatComposerPolicy.showComposer(
      accountMessagingBlocked: accountBlocked,
    );
    final isSupportThread = widget.conversationType == 'customer-support';
    final messagesAsync = ref.watch(customerChatMessagesStreamProvider(widget.chatId));

    ref.listen(customerChatMessagesStreamProvider(widget.chatId), (previous, next) {
      if (!next.hasValue) return;
      final messages = next.requireValue;
      if (!mounted) return;
      final u = ref.read(customerIdProvider).trim();
      final removeIds = _pending
          .where(
            (p) =>
                p.status == _PendingStatus.sending &&
                _pendingIsEchoedByStream(messages, u, p),
          )
          .map((p) => p.id)
          .toList();
      if (removeIds.isEmpty) return;
      setState(() => _pending.removeWhere((x) => removeIds.contains(x.id)));
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        title: Text(widget.name),
      ),
      body: Column(
        children: [
          if (!showComposer)
            const ChatReadOnlyBanner(
              message: "Your account can't send messages right now.",
            ),
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
                final entries = <({DateTime sortAt, Widget child})>[];
                for (final m in messages) {
                  final sid = (m['senderId'] as String? ?? '').trim();
                  final isMe = sid.isNotEmpty && sid == uidTrim;
                  final tone = _tone(isMe: isMe, isSupportThread: isSupportThread);
                  final senderLabel = _participantLabel(
                    isMe: isMe,
                    customerName: customerName,
                    isSupportThread: isSupportThread,
                  );
                  final sortAt = _parseMsgCreatedAt(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  entries.add((
                    sortAt: sortAt,
                    child: ChatMessageThreadRow(
                      roleLabel: senderLabel,
                      tone: tone,
                      alignEnd: isMe,
                      text: m['content'] as String? ?? '',
                      timeLabel: _formatTime(m['createdAt']),
                    ),
                  ));
                }
                for (final p in _pending) {
                  if (p.status == _PendingStatus.sending &&
                      _pendingIsEchoedByStream(messages, uidTrim, p)) {
                    continue;
                  }
                  entries.add((
                    sortAt: p.createdAt,
                    child: ChatMessageThreadRow(
                      roleLabel: _participantLabel(
                        isMe: true,
                        customerName: customerName,
                        isSupportThread: isSupportThread,
                      ),
                      tone: ChatBubbleTone.outgoing,
                      alignEnd: true,
                      text: p.text,
                      timeLabel: _time(p.createdAt),
                      sendState: p.status == _PendingStatus.sending
                          ? ChatOutgoingSendState.sending
                          : ChatOutgoingSendState.failed,
                      onRetryFailed: p.status == _PendingStatus.failed
                          ? () => _retryPending(p.id)
                          : null,
                    ),
                  ));
                }
                entries.sort((a, b) => a.sortAt.compareTo(b.sortAt));
                final items = entries.map((e) => e.child).toList();

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
                  padding: const EdgeInsets.all(ChatDesignTokens.listHorizontalPadding),
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
          if (showComposer)
            NahamChatInputBar(
              controller: _ctrl,
              sending: _sending,
              onSend: _send,
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

  static ChatBubbleTone _tone({
    required bool isMe,
    required bool isSupportThread,
  }) {
    if (isMe) return ChatBubbleTone.outgoing;
    if (isSupportThread) return ChatBubbleTone.support;
    return ChatBubbleTone.incoming;
  }

  /// Display name for the message row (customer name vs kitchen vs Support).
  String _participantLabel({
    required bool isMe,
    required String customerName,
    required bool isSupportThread,
  }) {
    if (isMe) {
      final n = customerName.trim();
      return n.isNotEmpty ? n : 'You';
    }
    if (isSupportThread) return 'Support';
    final peer = widget.name.trim();
    return peer.isNotEmpty ? peer : 'Cook';
  }
}
