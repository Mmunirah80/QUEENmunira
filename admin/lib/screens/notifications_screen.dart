import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/naham_screen_header.dart';
import '../core/widgets/naham_empty_screens.dart';
import '../core/utils/extensions.dart';
import '../providers/admin_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: NahamScreenHeader(title: 'الإشعارات')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.space16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(adminFirebaseDataSourceProvider).markAllNotificationsRead();
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('تعليم الكل كمقروء'),
                  ),
                ],
              ),
            ),
          ),
          notificationsAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: NahamEmptyStateContent(
                      title: 'لا إشعارات',
                      subtitle: 'ستظهر الإشعارات هنا.',
                      buttonLabel: 'تحديث',
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _NotificationTile(
                    id: list[i]['id'] as String,
                    title: list[i]['title'] as String? ?? '',
                    body: list[i]['body'] as String? ?? '',
                    createdAt: list[i]['createdAt'] as String?,
                    read: list[i]['read'] as bool? ?? false,
                    onTap: () => ref.read(adminFirebaseDataSourceProvider).markNotificationRead(list[i]['id'] as String),
                  ),
                  childCount: list.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(hasScrollBody: false, child: Center(child: LoadingWidget())),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('خطأ: $e', style: const TextStyle(color: AppDesignSystem.errorRed), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () => ref.invalidate(adminNotificationsProvider), child: const Text('إعادة المحاولة')),
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

class _NotificationTile extends StatelessWidget {
  final String id;
  final String title;
  final String body;
  final String? createdAt;
  final bool read;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.id,
    required this.title,
    required this.body,
    this.createdAt,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String timeStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt!);
        timeStr = dt.formattedTime;
      } catch (_) {}
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDesignSystem.space16, vertical: AppDesignSystem.space8),
      color: read ? null : NahamTheme.primary.withValues(alpha: 0.06),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: read ? NahamTheme.cardBackground : NahamTheme.primary,
          child: Icon(
            read ? Icons.notifications_none_rounded : Icons.notifications_rounded,
            color: read ? AppDesignSystem.textSecondary : Colors.white,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: read ? FontWeight.w600 : FontWeight.w700,
              ),
        ),
        subtitle: Text(
          body,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: timeStr.isNotEmpty ? Text(timeStr, style: Theme.of(context).textTheme.bodySmall) : null,
      ),
    );
  }
}
