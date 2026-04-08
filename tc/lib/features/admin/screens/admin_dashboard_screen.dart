import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/models/admin_dashboard_stats.dart';
import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_attention_section.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';
import 'admin_settings_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _invalidateDashboard(WidgetRef ref) {
    ref.invalidate(adminDashboardStatsProvider);
    ref.invalidate(adminOrderPipelineProvider);
    ref.invalidate(adminDashboardAnalyticsProvider);
    ref.invalidate(adminAlertsSummaryProvider);
    ref.read(adminPendingCookDocumentsNotifierProvider.notifier).refresh();
    ref.invalidate(adminDashboardRecentOrdersSampleProvider);
    ref.invalidate(adminDashboardReportedReelsProvider);
    ref.invalidate(adminDashboardSupportTicketsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;

    if (auth.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: const Text('Home'),
          actions: const [AdminSignOutIconButton()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null || !user.isAdmin || user.isBlocked) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(title: const Text('Home')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.black45),
                const SizedBox(height: 16),
                Text(
                  user?.isBlocked == true
                      ? 'This account is blocked. Contact support.'
                      : 'Access denied. Sign in with an admin account.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go(RouteNames.login);
                  },
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _invalidateDashboard(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const AdminSignOutIconButton(),
        ],
      ),
      body: statsAsync.when(
        loading: () => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Key metrics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Loading latest numbers…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              const AdminDashboardGridSkeleton(),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Failed to load home.\n$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _invalidateDashboard(ref),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async => _invalidateDashboard(ref),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Marketplace control center',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: const AdminSectionHeader(
                      title: 'Key metrics',
                      subtitle: 'Tap a card to jump to the right workspace',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final cross = w >= 720 ? 3 : 2;
                        final statsCards = _buildStatCards(ref, stats);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: cross >= 3 ? 1.42 : 1.48,
                          ),
                          itemCount: statsCards.length,
                          itemBuilder: (context, i) => statsCards[i],
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: AdminAttentionSection()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(builder: (_) => const AdminSettingsScreen()),
                          );
                        },
                        icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                        label: const Text('Privacy & cookies'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildStatCards(WidgetRef ref, AdminDashboardStats stats) {
    void kpiUsersCook() {
      ref.read(adminUsersHubTabProvider.notifier).state = 0;
      ref.read(adminUsersRoleTabProvider.notifier).state = AdminUsersRoleTab.cook;
      ref.read(adminUsersAccountFilterProvider.notifier).state = AdminUsersAccountFilter.all;
      ref.read(adminBottomNavIndexProvider.notifier).state = 1;
    }

    void kpiPendingApps() {
      ref.read(adminInspectionTabProvider.notifier).state = 0;
      ref.read(adminUsersHubTabProvider.notifier).state = 1;
      ref.read(adminBottomNavIndexProvider.notifier).state = 1;
    }

    void kpiOrdersTab(int index) {
      ref.read(adminOrdersStuckOnlyProvider.notifier).state = false;
      ref.read(adminOrdersTargetTabProvider.notifier).state = index;
      ref.read(adminBottomNavIndexProvider.notifier).state = 2;
    }

    void kpiReportedReels() {
      ref.read(adminReelsModerationFilterProvider.notifier).state = AdminReelsModerationFilter.reported;
      ref.read(adminBottomNavIndexProvider.notifier).state = 4;
    }

    void kpiFrozenCooks() {
      ref.read(adminUsersHubTabProvider.notifier).state = 0;
      ref.read(adminUsersRoleTabProvider.notifier).state = AdminUsersRoleTab.cook;
      ref.read(adminUsersAccountFilterProvider.notifier).state = AdminUsersAccountFilter.frozenOrBlocked;
      ref.read(adminBottomNavIndexProvider.notifier).state = 1;
    }

    return [
      AdminKpiCard(
        accent: AdminKpiAccent.orders,
        title: 'Orders today',
        value: '${stats.ordersToday}',
        onTap: () => kpiOrdersTab(0),
      ),
      AdminKpiCard(
        accent: AdminKpiAccent.cooks,
        title: 'Cooks',
        value: '${stats.totalCooks}',
        onTap: kpiUsersCook,
      ),
      AdminKpiCard(
        accent: AdminKpiAccent.risk,
        title: 'Frozen or blocked',
        value: '${stats.frozenAccounts}',
        onTap: kpiFrozenCooks,
      ),
      AdminKpiCard(
        accent: AdminKpiAccent.reports,
        title: 'Reports (reels)',
        value: '${stats.reportedContent}',
        onTap: kpiReportedReels,
      ),
      AdminKpiCard(
        accent: AdminKpiAccent.activePipeline,
        title: 'Active orders',
        value: '${stats.activeOrders}',
        onTap: () => kpiOrdersTab(1),
      ),
      AdminKpiCard(
        accent: AdminKpiAccent.pending,
        title: 'Pending applications',
        value: '${stats.pendingApplications}',
        onTap: kpiPendingApps,
      ),
    ];
  }
}
