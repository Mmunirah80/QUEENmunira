// ============================================================
// COOK EARNINGS — Firestore only (orders), RTL, TC theme. Loading/error/empty.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../features/orders/domain/entities/chef_today_stats.dart';
import '../../../features/orders/presentation/orders_failure.dart';
import '../../../features/orders/presentation/providers/orders_provider.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const primaryDark = AppDesignSystem.primaryDark;
  static const primaryMid = AppDesignSystem.primaryMid;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
  static const border = Color(0xFFE8E0F5);
}

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(chefTodayStatsProvider);
    final summaryAsync = ref.watch(chefEarningsSummaryProvider);
    final monthlyAsync = ref.watch(chefMonthlyInsightsProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        body: todayAsync.when(
          data: (today) {
            return summaryAsync.when(
              data: (summary) {
                return monthlyAsync.when(
                  data: (monthly) {
                    final hasAnyData = summary.totalCount > 0 ||
                        today.completedOrdersToday > 0 ||
                        today.inKitchenCountToday > 0 ||
                        monthly.monthOrders > 0;
                    if (!hasAnyData) {
                      return _buildEmpty(context);
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(chefTodayStatsProvider);
                        ref.invalidate(chefEarningsSummaryProvider);
                        ref.invalidate(chefMonthlyInsightsProvider);
                      },
                      child: CustomScrollView(
                        slivers: [
                        _buildHeader(context),
                        SliverToBoxAdapter(
                          child: _buildPayoutCards(
                            today,
                            summary,
                            monthly,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildWeeklyChart(summary.last7DaysEarnings),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: LoadingWidget()),
                  error: (e, _) => _buildError(context, ref, e),
                );
              },
              loading: () => const Center(child: LoadingWidget()),
              error: (e, _) => _buildError(context, ref, e),
            );
          },
          loading: () => const Center(child: LoadingWidget()),
          error: (e, _) => _buildError(context, ref, e),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildHeader(context),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_rounded, size: 64, color: _NC.primaryLight),
                const SizedBox(height: 16),
                const Text('No earnings yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _NC.text)),
                const SizedBox(height: 8),
                const Text('Your earnings will appear here after you complete orders.', style: TextStyle(fontSize: 14, color: _NC.textSub)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, [Object? error]) {
    final message =
        error != null ? resolveOrdersUiError(error) : 'Something went wrong. Please try again.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppDesignSystem.errorRed),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.invalidate(chefTodayStatsProvider);
                ref.invalidate(chefEarningsSummaryProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_NC.primary, _NC.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Earnings & Insights',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutCards(
    ChefTodayStats today,
    ({double totalEarnings, int totalCount, List<double> last7DaysEarnings}) summary,
    ({double monthEarnings, int monthOrders, String topDish, double acceptanceRate}) monthly,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Monthly insights (current calendar month, backed by Supabase orders).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _NC.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _NC.border),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This month overview',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _NC.text),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Earnings: ${monthly.monthEarnings.toStringAsFixed(1)} SAR',
                  style: const TextStyle(fontSize: 13, color: _NC.text),
                ),
                Text(
                  '• Orders: ${monthly.monthOrders}',
                  style: const TextStyle(fontSize: 13, color: _NC.text),
                ),
                Text(
                  '• Top dish: ${monthly.topDish}',
                  style: const TextStyle(fontSize: 13, color: _NC.text),
                ),
                Text(
                  '• Acceptance rate: ${monthly.acceptanceRate.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 13, color: _NC.text),
                ),
              ],
            ),
          ),
          _card(
            icon: Icons.today_rounded,
            title: 'Today (completed)',
            amount: today.completedRevenueToday,
            subtitle:
                '${today.completedOrdersToday} completed · ${today.inKitchenCountToday} in kitchen',
            footnote: today.pipelineOrderValueToday > 0
                ? 'In-kitchen order value today: ${today.pipelineOrderValueToday.toStringAsFixed(1)} SAR'
                : null,
          ),
          const SizedBox(height: 12),
          _card(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Total earnings (last 30 days)',
            amount: summary.totalEarnings,
            subtitle: '${summary.totalCount} completed orders',
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required double amount,
    required String subtitle,
    String? footnote,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _NC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _NC.border),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _NC.primaryLight, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: _NC.primaryMid, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: _NC.textSub)),
                Row(
                  children: [
                    Text(
                      '${amount.toStringAsFixed(1)} SAR',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _NC.primaryMid),
                    ),
                  ],
                ),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _NC.textSub)),
                if (footnote != null) ...[
                  const SizedBox(height: 6),
                  Text(footnote, style: const TextStyle(fontSize: 10, color: _NC.textSub)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(List<double> data) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final max = data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);
    final safeMax = max <= 0 ? 1.0 : max;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _NC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _NC.border),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _NC.primaryLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.bar_chart_rounded, color: _NC.primaryMid, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Weekly earnings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _NC.text)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final h = data.length > i ? (data[i] / safeMax) * 100 : 0.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: h.clamp(4.0, 120),
                      decoration: BoxDecoration(
                        color: _NC.primaryMid.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(days[i], style: const TextStyle(fontSize: 10, color: _NC.textSub)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
