import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/naham_screen_header.dart';
import '../core/constants/route_names.dart';
import '../providers/admin_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delayed = ref.watch(delayedOrdersCountProvider);
    final pendingChefs = ref.watch(pendingChefsCountProvider);
    final supportUnread = ref.watch(supportUnreadCountProvider);
    final todayOrders = ref.watch(todayOrdersCountProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: NahamScreenHeader(title: 'لوحة التحكم'),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppDesignSystem.screenHorizontalPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppDesignSystem.space16),
                _StatsGrid(
                  delayed: delayed,
                  pendingChefs: pendingChefs,
                  supportUnread: supportUnread,
                  todayOrders: todayOrders,
                  todayRevenue: todayRevenue,
                ),
                const SizedBox(height: AppDesignSystem.space24),
                Text(
                  'إجراءات سريعة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDesignSystem.space12),
                _QuickActionsGrid(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AsyncValue<int> delayed;
  final AsyncValue<int> pendingChefs;
  final AsyncValue<int> supportUnread;
  final AsyncValue<int> todayOrders;
  final AsyncValue<double> todayRevenue;

  const _StatsGrid({
    required this.delayed,
    required this.pendingChefs,
    required this.supportUnread,
    required this.todayOrders,
    required this.todayRevenue,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppDesignSystem.space16,
      crossAxisSpacing: AppDesignSystem.space16,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          title: 'طلبات متأخرة',
          asyncValue: delayed,
          icon: Icons.schedule_rounded,
          color: AppDesignSystem.warningOrange,
        ),
        _StatCard(
          title: 'موافقات الطباخين',
          asyncValue: pendingChefs,
          icon: Icons.how_to_reg_rounded,
          color: NahamTheme.primary,
        ),
        _StatCard(
          title: 'دردشات غير مقروءة',
          asyncValue: supportUnread,
          icon: Icons.chat_rounded,
          color: NahamTheme.secondary,
        ),
        _StatCard(
          title: 'طلبات اليوم',
          asyncValue: todayOrders,
          icon: Icons.receipt_long_rounded,
          color: NahamTheme.primary,
        ),
        _StatCard(
          title: 'إيرادات اليوم',
          asyncValue: todayRevenue,
          icon: Icons.payments_rounded,
          color: AppDesignSystem.successGreen,
          isRevenue: true,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final AsyncValue<Object> asyncValue;
  final IconData icon;
  final Color color;
  final bool isRevenue;

  const _StatCard({
    required this.title,
    required this.asyncValue,
    required this.icon,
    required this.color,
    this.isRevenue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppDesignSystem.elevationCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.space16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppDesignSystem.space8),
            asyncValue.when(
              data: (v) => Text(
                isRevenue ? '${v is num ? (v).toStringAsFixed(0) : v.toString()} ر.س' : '$v',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NahamTheme.textOnLight,
                    ),
              ),
              loading: () => const SizedBox(
                height: 28,
                child: LoadingWidget(),
              ),
              error: (_, __) => Text(
                '—',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NahamTheme.textOnLight,
                    ),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      ('الموافقات المعلقة', Icons.how_to_reg_rounded, RouteNames.pendingApproval),
      ('إدارة الطلبات', Icons.receipt_long_rounded, RouteNames.orders),
      ('إدارة المستخدمين', Icons.people_rounded, RouteNames.userManagement),
      ('النقد والمدفوعات', Icons.payments_rounded, RouteNames.cashManagement),
      ('التفتيش الصحي', Icons.video_call_rounded, RouteNames.hygieneInspection),
      ('التحليلات', Icons.bar_chart_rounded, RouteNames.analytics),
      ('الدردشة والدعم', Icons.chat_rounded, RouteNames.chatSupport),
      ('الإشعارات', Icons.notifications_rounded, RouteNames.notifications),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppDesignSystem.space12,
      crossAxisSpacing: AppDesignSystem.space12,
      childAspectRatio: 1.2,
      children: actions
          .map(
            (a) => Card(
              elevation: AppDesignSystem.elevationCard,
              child: InkWell(
                onTap: () => context.go(a.$3),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.space16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(a.$2, color: NahamTheme.primary, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        a.$1,
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
