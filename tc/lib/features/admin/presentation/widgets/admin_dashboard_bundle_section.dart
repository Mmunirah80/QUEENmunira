import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import 'admin_chart_shell.dart';
import 'admin_design_system_widgets.dart';
import 'admin_insights_fl_chart.dart';

/// RPC-backed charts for the main dashboard (14-day window).
class AdminDashboardBundleSection extends ConsumerWidget {
  const AdminDashboardBundleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardAnalyticsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Insight charts unavailable. Deploy get_admin_analytics_bundle RPC.\n$e'),
      ),
      data: (b) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AdminSectionHeader(
                title: 'Trends & rankings',
                subtitle: 'Aggregated from Supabase (live orders, items, profiles).',
              ),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 720;
                  final lineOrders = AdminChartShell(
                    title: 'Orders by day',
                    subtitle: 'Line chart · recent window',
                    child: AdminOrdersByDayLineChart(points: b.ordersByDay),
                  );
                  final lineRev = AdminChartShell(
                    title: 'Revenue by day',
                    subtitle: 'Completed pipeline revenue',
                    child: AdminRevenueLineChart(points: b.revenueByDay),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: lineOrders),
                        const SizedBox(width: 12),
                        Expanded(child: lineRev),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      lineOrders,
                      const SizedBox(height: 12),
                      lineRev,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 720;
                  final barM = AdminChartShell(
                    title: 'Orders by month',
                    child: AdminMonthlyOrdersBarChart(months: b.ordersByMonth),
                  );
                  final peak = AdminChartShell(
                    title: 'Peak order hours (UTC)',
                    child: AdminPeakHoursBarChart(hours: b.peakOrderHours),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: barM),
                        const SizedBox(width: 12),
                        Expanded(child: peak),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      barM,
                      const SizedBox(height: 12),
                      peak,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 720;
                  final growth = AdminChartShell(
                    title: 'New user signups by day',
                    child: AdminUserSignupLineChart(points: b.userGrowthByDay),
                  );
                  final pie = AdminChartShell(
                    title: 'Application status distribution',
                    subtitle: 'Cook document statuses',
                    minHeight: 220,
                    child: AdminApplicationPieChart(pie: b.applicationStatusPie),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: growth),
                        const SizedBox(width: 12),
                        Expanded(child: pie),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      growth,
                      const SizedBox(height: 12),
                      pie,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _rankRow(context, 'Top requested cooks', b.topRequestedCooks.map((c) => '${c.name} · ${c.orderCount} orders').toList()),
              _rankRow(context, 'Top selling dishes', b.topSellingDishes.map((d) => '${d.dishName} · ${d.ordersCount} orders').toList()),
              _rankRow(context, 'Most active customers', b.mostActiveCustomers.map((c) => '${c.name} · ${c.orderCount} orders').toList()),
              _rankRow(
                context,
                'Highest rated cooks',
                b.highestRatedCooks.isEmpty
                    ? const <String>[]
                    : b.highestRatedCooks
                        .map((c) => '${c.name} · ${c.rating != null ? c.rating!.toStringAsFixed(2) : '—'} ★')
                        .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _rankRow(BuildContext context, String title, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final line in lines.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
