import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_providers.dart';
import 'admin_production_widgets.dart';
import 'admin_design_system_widgets.dart';
import '../../screens/admin_expired_documents_screen.dart';

/// “Attention needed” — counts from [get_admin_alerts_summary] with navigation.
class AdminAttentionSection extends ConsumerWidget {
  const AdminAttentionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAlertsSummaryProvider);

    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: DecoratedBox(
          decoration: AdminPanelTokens.surfaceCard(context, Theme.of(context).colorScheme),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Could not load alerts', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (a) {
        if (a.totalAttention == 0) {
          final scheme = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: DecoratedBox(
              decoration: AdminPanelTokens.surfaceCard(context, scheme),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: scheme.primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All clear',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No urgent moderation items right now.',
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AdminSectionHeader(
                title: 'Needs attention',
                subtitle: 'Tap a row to jump to the right workspace',
              ),
              AlertCard(
                title: 'Expired Documents',
                count: a.expiredDocuments,
                icon: Icons.event_busy_rounded,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const AdminExpiredDocumentsScreen()),
                  );
                },
              ),
              AlertCard(
                title: 'Pending Applications',
                count: a.pendingApplications,
                icon: Icons.pending_actions_outlined,
                onTap: () {
                  ref.read(adminInspectionTabProvider.notifier).state = 0;
                  ref.read(adminUsersHubTabProvider.notifier).state = 1;
                  ref.read(adminBottomNavIndexProvider.notifier).state = 1;
                },
              ),
              AlertCard(
                title: 'Frozen Accounts',
                count: a.frozenAccounts,
                icon: Icons.ac_unit_rounded,
                onTap: () {
                  ref.read(adminUsersHubTabProvider.notifier).state = 0;
                  ref.read(adminBottomNavIndexProvider.notifier).state = 1;
                },
              ),
              AlertCard(
                title: 'Reported Reels',
                count: a.reportedReels,
                icon: Icons.flag_outlined,
                onTap: () {
                  ref.read(adminReelsModerationFilterProvider.notifier).state =
                      AdminReelsModerationFilter.reported;
                  ref.read(adminBottomNavIndexProvider.notifier).state = 4;
                },
              ),
              AlertCard(
                title: 'Chats to review',
                count: a.chatsNeedingReview,
                icon: Icons.support_agent_rounded,
                onTap: () {
                  ref.read(adminBottomNavIndexProvider.notifier).state = 3;
                },
              ),
              AlertCard(
                title: 'Orders Delayed',
                count: a.ordersStuck,
                icon: Icons.hourglass_bottom_rounded,
                onTap: () {
                  ref.read(adminOrdersStuckOnlyProvider.notifier).state = true;
                  ref.read(adminBottomNavIndexProvider.notifier).state = 2;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
