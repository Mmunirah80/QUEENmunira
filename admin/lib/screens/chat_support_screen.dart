import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/constants/route_names.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/naham_screen_header.dart';
import '../core/widgets/naham_empty_screens.dart';
import '../providers/admin_providers.dart';

class ChatSupportScreen extends ConsumerWidget {
  const ChatSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(supportConversationsProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const NahamScreenHeader(title: 'الدردشة والدعم'),
          Expanded(
            child: conversationsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: NahamEmptyStateContent(
                      title: 'لا محادثات',
                      subtitle: 'ستظهر محادثات الدعم هنا.',
                      buttonLabel: 'تحديث',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppDesignSystem.space16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return _ChatTile(
                      participantName: c['participantName'] as String? ?? '—',
                      lastMessage: c['lastMessage'] as String? ?? '',
                      updatedAt: c['updatedAt'] as String?,
                      unread: c['unreadCount'] as int? ?? 0,
                      onTap: () => context.push(
                        RouteNames.supportConversation,
                        extra: {
                          'conversationId': c['id'],
                          'participantName': c['participantName'] ?? '—',
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: LoadingWidget()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('خطأ: $e', style: const TextStyle(color: AppDesignSystem.errorRed)),
                    TextButton(onPressed: () => ref.invalidate(supportConversationsProvider), child: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String participantName;
  final String lastMessage;
  final String? updatedAt;
  final int unread;
  final VoidCallback onTap;

  const _ChatTile({
    required this.participantName,
    required this.lastMessage,
    this.updatedAt,
    this.unread = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String timeStr = '';
    if (updatedAt != null) {
      try {
        final dt = DateTime.parse(updatedAt!);
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return Card(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.space12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: NahamTheme.primary.withValues(alpha: 0.2),
          child: Text(
            participantName.isNotEmpty ? participantName[0] : '?',
            style: const TextStyle(color: NahamTheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(participantName),
        subtitle: Text(lastMessage, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (timeStr.isNotEmpty) Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: NahamTheme.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
