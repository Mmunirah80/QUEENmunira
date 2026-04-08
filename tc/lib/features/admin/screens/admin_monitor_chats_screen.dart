import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../features/orders/presentation/orders_failure.dart';
import '../../chat/domain/entities/chat_entity.dart';
import '../../../features/chat/presentation/chat_composer_policy.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../../../features/chat/presentation/widgets/chat_design_tokens.dart';
import '../../../features/chat/presentation/widgets/chat_message_bubble.dart';
import '../../../features/chat/presentation/widgets/chat_message_thread_row.dart';
import '../../../features/chat/presentation/widgets/chat_monitor_banner.dart';
import '../../../features/chat/presentation/widgets/naham_chat_input_bar.dart';
import '../presentation/chat_admin_message_labels.dart';
import '../presentation/providers/admin_monitor_chats_provider.dart';
import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';
import '../services/admin_actions_service.dart';
import 'admin_orders_screen.dart';

/// Order-linked threads and support inboxes for admin review.
class AdminSupportChatsScreen extends ConsumerStatefulWidget {
  const AdminSupportChatsScreen({super.key});

  @override
  ConsumerState<AdminSupportChatsScreen> createState() => _AdminSupportChatsScreenState();
}

class _AdminSupportChatsScreenState extends ConsumerState<AdminSupportChatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _topTab;
  final _monitorSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _topTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _topTab.dispose();
    _monitorSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Chat'),
        actions: const [AdminSignOutIconButton()],
        bottom: TabBar(
          controller: _topTab,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Order chats'),
            Tab(text: 'Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _topTab,
        children: [
          _MonitorOrderChatsTab(
            searchCtrl: _monitorSearch,
            asyncList: ref.watch(adminOrderMonitorChatsStreamProvider),
            onRetry: () => ref.invalidate(adminOrderMonitorChatsStreamProvider),
          ),
          const _SupportMergedTab(),
        ],
      ),
    );
  }
}

class _MonitorOrderChatsTab extends ConsumerStatefulWidget {
  const _MonitorOrderChatsTab({
    required this.searchCtrl,
    required this.asyncList,
    required this.onRetry,
  });

  final TextEditingController searchCtrl;
  final AsyncValue<List<Map<String, dynamic>>> asyncList;
  final VoidCallback onRetry;

  @override
  ConsumerState<_MonitorOrderChatsTab> createState() => _MonitorOrderChatsTabState();
}

class _MonitorOrderChatsTabState extends ConsumerState<_MonitorOrderChatsTab> {
  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearch);
    super.dispose();
  }

  void _onSearch() => setState(() {});

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows) {
    final q = widget.searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((r) {
      final orderRef = (r['orderRef'] ?? '').toString().toLowerCase();
      final orderId = (r['orderId'] ?? '').toString().toLowerCase();
      final cust = (r['customerLabel'] ?? '').toString().toLowerCase();
      final cook = (r['cookLabel'] ?? '').toString().toLowerCase();
      return orderRef.contains(q) ||
          orderId.contains(q) ||
          cust.contains(q) ||
          cook.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return widget.asyncList.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(resolveOrdersUiError(e), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (items) {
        final filtered = _filter(items);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: widget.searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search order, Cook, or customer',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppDesignSystem.cardWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  isDense: true,
                ),
              ),
            ),
            if (filtered.isEmpty)
              Expanded(
                child: AdminEmptyState(
                  icon: items.isEmpty ? Icons.chat_bubble_outline_rounded : Icons.search_off_rounded,
                  title: items.isEmpty ? 'No conversations yet' : 'No matching conversations',
                  subtitle: items.isEmpty
                      ? 'Order-linked chats will appear when customers message kitchens.'
                      : 'Try a different search.',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = filtered[i];
                    final id = (r['conversationId'] ?? r['id'] ?? '').toString();
                    final orderRef = (r['orderRef'] ?? '').toString();
                    final orderId = (r['orderId'] ?? '').toString();
                    final orderChip = orderRef.isNotEmpty
                        ? orderRef
                        : (orderId.length > 8 ? orderId.substring(0, 8) : orderId);
                    final cook = (r['cookLabel'] ?? '').toString();
                    final cust = (r['customerLabel'] ?? '').toString();
                    final last = (r['lastMessage'] ?? '—').toString();
                    final at = r['lastMessageAt'] as DateTime? ?? DateTime.now();

                    final scheme = Theme.of(context).colorScheme;
                    final radius = BorderRadius.circular(AdminPanelTokens.cardRadius);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: radius,
                        onTap: id.isEmpty
                            ? null
                            : () {
                                final title = orderChip.isNotEmpty
                                    ? 'Order Chat #$orderChip'
                                    : (cook.trim().isEmpty && cust.trim().isEmpty
                                        ? 'Order chat'
                                        : '${cook.isEmpty ? 'Kitchen' : cook} · ${cust.isEmpty ? 'Customer' : cust}');
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AdminSupportConversationScreen(
                                      chatId: id,
                                      title: title,
                                      conversationType: 'customer-chef',
                                      monitorOnly: true,
                                    ),
                                  ),
                                );
                              },
                        child: Ink(
                          decoration: AdminPanelTokens.surfaceCard(context, scheme),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AdminPanelTokens.space16,
                              vertical: AdminPanelTokens.space12,
                            ),
                            minVerticalPadding: AdminPanelTokens.space12,
                            title: Text(
                              orderChip.isNotEmpty
                                  ? 'Order Chat #$orderChip'
                                  : (cook.trim().isEmpty && cust.trim().isEmpty
                                      ? 'Conversation'
                                      : '${cook.isEmpty ? 'Kitchen' : cook} · ${cust.isEmpty ? 'Customer' : cust}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                            ),
                            subtitle: Text(
                              '${cook.isNotEmpty ? cook : '—'} · ${cust.isNotEmpty ? cust : '—'} · $last',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, height: 1.25, color: scheme.onSurfaceVariant),
                            ),
                            trailing: Text(
                              DateFormat.MMMd().add_jm().format(at.toLocal()),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SupportMergedTab extends ConsumerWidget {
  const _SupportMergedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chefAsync = ref.watch(adminChefSupportInboxStreamProvider);
    final custAsync = ref.watch(adminCustomerSupportInboxStreamProvider);

    Widget retryChef() => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(adminChefSupportInboxStreamProvider),
            child: const Text('Retry'),
          ),
        );
    Widget retryCust() => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(adminCustomerSupportInboxStreamProvider),
            child: const Text('Retry'),
          ),
        );

    return chefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
      error: (e, _) => retryChef(),
      data: (chefRows) => custAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
        error: (e, _) => retryCust(),
        data: (custRows) {
          final merged = <Map<String, dynamic>>[
            ...chefRows.map((r) => {...r, '_lane': 'Cook'}),
            ...custRows.map((r) => {...r, '_lane': 'Customer'}),
          ];
          merged.sort((a, b) {
            final ta = a['lastMessageAt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
            final tb = b['lastMessageAt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
            return tb.compareTo(ta);
          });
          if (merged.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.support_agent_outlined,
              title: 'No support messages',
              subtitle: 'Cook and customer support threads will show here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: merged.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final row = merged[i];
              final lane = row['_lane'] as String? ?? '';
              final title = row['title'] as String? ?? 'Support';
              final last = row['lastMessage'] as String? ?? '—';
              final at = row['lastMessageAt'] as DateTime? ?? DateTime.now();
              final id = row['id'] as String? ?? '';
              final convType = row['type'] as String? ?? 'chef-admin';
              final scheme = Theme.of(context).colorScheme;
              final radius = BorderRadius.circular(AdminPanelTokens.cardRadius);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: radius,
                  onTap: id.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminSupportConversationScreen(
                                chatId: id,
                                title: 'Support',
                                conversationType: convType,
                                monitorOnly: false,
                              ),
                            ),
                          );
                        },
                  child: Ink(
                    decoration: AdminPanelTokens.surfaceCard(context, scheme),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AdminPanelTokens.space16,
                        vertical: AdminPanelTokens.space12,
                      ),
                      minVerticalPadding: AdminPanelTokens.space12,
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                      ),
                      subtitle: Text(
                        '$lane · $last',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                      trailing: Text(
                        DateFormat.MMMd().add_jm().format(at.toLocal()),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminSupportConversationScreen extends ConsumerStatefulWidget {
  const AdminSupportConversationScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.conversationType,
    this.monitorOnly = false,
  });

  final String chatId;
  final String title;
  /// `customer-chef` | `chef-admin` | `customer-support`
  final String conversationType;

  /// When true, admin can read messages but cannot send (order-thread monitoring).
  final bool monitorOnly;

  @override
  ConsumerState<AdminSupportConversationScreen> createState() =>
      _AdminSupportConversationScreenState();
}

class _AdminSupportConversationScreenState extends ConsumerState<AdminSupportConversationScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!ChatComposerPolicy.showComposer(adminMonitorReadOnly: widget.monitorOnly)) {
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(adminChatSessionUserIdProvider);
    if (uid.isEmpty) return;
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client.from('messages').insert(<String, dynamic>{
        'conversation_id': widget.chatId,
        'sender_id': uid,
        'content': text,
        'is_read': false,
        'created_at': now,
      });
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showChatModerationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(ctx).bottom + 16),
          child: Consumer(
            builder: (ctx, ref, _) {
              final metaAsync = ref.watch(adminConversationMetaProvider(widget.chatId));
              return metaAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text('Could not load details'),
                data: (meta) {
                  final mod = (meta?['admin_moderation_state'] ?? 'none').toString();
                  final reviewedRaw = meta?['admin_reviewed_at'];
                  final reviewed =
                      reviewedRaw != null && reviewedRaw.toString().trim().isNotEmpty;
                  final actions = ref.read(adminActionsServiceProvider);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: mod == 'reported' || mod == 'flagged' || mod == 'none' ? mod : 'none',
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(value: 'reported', child: Text('Reported')),
                          DropdownMenuItem(value: 'flagged', child: Text('Flagged')),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          await actions.updateConversationModeration(
                            ctx,
                            conversationId: widget.chatId,
                            moderationState: v,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: reviewed
                            ? null
                            : () async {
                                await actions.updateConversationModeration(
                                  ctx,
                                  conversationId: widget.chatId,
                                  markReviewedNow: true,
                                );
                              },
                        child: const Text('Mark reviewed'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: !reviewed
                            ? null
                            : () async {
                                await actions.updateConversationModeration(
                                  ctx,
                                  conversationId: widget.chatId,
                                  clearReviewedAt: true,
                                );
                              },
                        child: const Text('Undo review'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminId = ref.watch(adminChatSessionUserIdProvider);
    final messagesAsync = ref.watch(messagesStreamProvider(widget.chatId));
    final metaAsync = ref.watch(adminConversationMetaProvider(widget.chatId));

    final customerId = (metaAsync.valueOrNull?['customer_id'] ?? '').toString();
    final chefId = (metaAsync.valueOrNull?['chef_id'] ?? '').toString();
    final convType = (metaAsync.valueOrNull?['type'] ?? widget.conversationType).toString();
    final headerCustomer = (metaAsync.valueOrNull?['_header_customer'] ?? '').toString().trim();
    final headerCook = (metaAsync.valueOrNull?['_header_cook'] ?? '').toString().trim();

    final isOrderChat = convType == 'customer-chef';
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        title: metaAsync.when(
          loading: () => Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          error: (_, __) => Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          data: (meta) {
            if (!isOrderChat || meta == null) {
              return Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            }
            final cust = (meta['_header_customer'] ?? '').toString().trim();
            final cook = (meta['_header_cook'] ?? '').toString().trim();
            final oid = (meta['order_id'] ?? '').toString().trim();
            final shortOrder = oid.length > 8 ? oid.substring(0, 8) : oid;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (oid.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminOrderDetailScreen(orderId: oid),
                        ),
                      );
                    },
                    child: Text(
                      'Order Chat #$shortOrder',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  )
                else
                  Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  cook.isNotEmpty || cust.isNotEmpty
                      ? '${cook.isEmpty ? '—' : cook} · ${cust.isEmpty ? '—' : cust}'
                      : 'Admin support',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Conversation details',
            onPressed: () => _showChatModerationSheet(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.monitorOnly) const ChatMonitorBanner(),
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
                  padding: const EdgeInsets.all(ChatDesignTokens.listHorizontalPadding),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final role = resolveAdminMessageSenderRole(
                      senderId: msg.senderId,
                      adminId: adminId,
                      conversationType: convType,
                      customerId: customerId,
                      chefId: chefId,
                    );
                    final senderDisplay = adminChatSenderDisplayName(
                      senderId: msg.senderId,
                      adminId: adminId,
                      customerId: customerId,
                      chefId: chefId,
                      headerCustomer: headerCustomer,
                      headerCook: headerCook,
                    );
                    final supportLane =
                        convType == 'customer-support' || convType == 'chef-admin';
                    final label = adminChatMessageRoleLabel(
                      role: role,
                      senderDisplay: senderDisplay,
                      supportLane: supportLane,
                    );
                    final alignEnd = role == AdminMessageSenderRole.admin;
                    final tone = role == AdminMessageSenderRole.admin
                        ? ChatBubbleTone.support
                        : ChatBubbleTone.incoming;

                    return ChatMessageThreadRow(
                      roleLabel: label,
                      tone: tone,
                      alignEnd: alignEnd,
                      text: msg.content,
                      timeLabel: DateFormat.jm().format(msg.timestamp.toLocal()),
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
          if (!widget.monitorOnly)
            NahamChatInputBar(
              controller: _ctrl,
              sending: _sending,
              onSend: _send,
              hintText: 'Message',
            ),
        ],
      ),
    );
  }
}
