import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../data/models/admin_analytics_bundle.dart';
import '../providers/admin_providers.dart';
import 'admin_design_system_widgets.dart';
import 'admin_insight_card.dart';

/// Derives seven headline insights from [AdminAnalyticsBundle] (no fabricated values).
class AdminDashboardInsightsSection extends ConsumerWidget {
  const AdminDashboardInsightsSection({super.key});

  static TimeSeriesPoint? _peakDay(List<TimeSeriesPoint> points) {
    if (points.isEmpty) return null;
    TimeSeriesPoint? best;
    for (final p in points) {
      if (best == null || p.value > best.value) best = p;
    }
    return best;
  }

  static NamedCount? _peakMonth(List<NamedCount> months) {
    if (months.isEmpty) return null;
    NamedCount? best;
    for (final m in months) {
      if (best == null || m.count > best.count) best = m;
    }
    return best;
  }

  static HourCount? _peakHour(List<HourCount> hours) {
    if (hours.isEmpty) return null;
    HourCount? best;
    for (final h in hours) {
      if (best == null || h.count > best.count) best = h;
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardAnalyticsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (b) {
        final topCook = b.topRequestedCooks.isNotEmpty ? b.topRequestedCooks.first : null;
        final topDish = b.topSellingDishes.isNotEmpty ? b.topSellingDishes.first : null;
        final peakDay = _peakDay(b.ordersByDay);
        final peakMonth = _peakMonth(b.ordersByMonth);
        final peakHr = _peakHour(b.peakOrderHours);
        final topCustomer = b.mostActiveCustomers.isNotEmpty ? b.mostActiveCustomers.first : null;
        CookRank? ratedCook;
        for (final c in b.highestRatedCooks) {
          if (c.rating != null) {
            ratedCook = c;
            break;
          }
        }

        String fmtDay(TimeSeriesPoint? p) {
          if (p == null || p.date.isEmpty) return 'No data';
          if (p.value <= 0) return 'No orders in window';
          final short = p.date.length >= 10 ? p.date.substring(0, 10) : p.date;
          return '$short · ${p.value} orders';
        }

        String fmtMonth(NamedCount? m) {
          if (m == null || m.name.isEmpty) return 'No data';
          if (m.count <= 0) return 'No orders in window';
          return '${m.name} · ${m.count} orders';
        }

        String fmtHour(HourCount? h) {
          if (h == null) return 'No data';
          if (h.count <= 0) return 'No orders in window';
          return 'Hour ${h.hour} (UTC) · ${h.count} orders';
        }

        void pushCook(String? id) {
          final uid = id?.trim() ?? '';
          if (uid.isEmpty) return;
          context.push(RouteNames.adminUserDetail(uid));
        }

        void pushCustomer(String? id) {
          final uid = id?.trim() ?? '';
          if (uid.isEmpty) return;
          context.push(RouteNames.adminUserDetail(uid));
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AdminSectionHeader(
                title: 'Smart insights',
                subtitle: 'From live analytics bundle (recent window). Tap people rows to open profile.',
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminInsightCard(
                      title: 'Most requested cook',
                      value: topCook == null || topCook.name.isEmpty ? 'No data' : topCook.name,
                      subtitle: topCook != null && topCook.orderCount > 0 ? '${topCook.orderCount} orders' : null,
                      onTap: topCook != null && topCook.cookId.isNotEmpty ? () => pushCook(topCook.cookId) : null,
                    ),
                    const SizedBox(width: 10),
                    AdminInsightCard(
                      title: 'Top selling dish',
                      value: topDish == null || topDish.dishName.isEmpty ? 'No data' : topDish.dishName,
                      subtitle: topDish != null && topDish.ordersCount > 0 ? '${topDish.ordersCount} orders' : null,
                    ),
                    const SizedBox(width: 10),
                    AdminInsightCard(
                      title: 'Peak order day',
                      value: fmtDay(peakDay),
                    ),
                    const SizedBox(width: 10),
                    AdminInsightCard(
                      title: 'Peak order month',
                      value: fmtMonth(peakMonth),
                    ),
                    const SizedBox(width: 10),
                    AdminInsightCard(
                      title: 'Peak order hour',
                      value: fmtHour(peakHr),
                    ),
                    const SizedBox(width: 10),
                    AdminInsightCard(
                      title: 'Most active customer',
                      value: topCustomer == null || topCustomer.name.isEmpty ? 'No data' : topCustomer.name,
                      subtitle: topCustomer != null && topCustomer.orderCount > 0 ? '${topCustomer.orderCount} orders' : null,
                      onTap: topCustomer != null && topCustomer.customerId.isNotEmpty
                          ? () => pushCustomer(topCustomer.customerId)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    AdminInsightCard(
                      title: 'Highest rated cook',
                      value: ratedCook == null
                          ? 'No data'
                          : (ratedCook.name.isEmpty ? ratedCook.cookId : ratedCook.name),
                      subtitle: ratedCook?.rating != null
                          ? '${ratedCook!.rating!.toStringAsFixed(2)} ★'
                          : null,
                      onTap: ratedCook == null || ratedCook.cookId.isEmpty
                          ? null
                          : () {
                              final c = ratedCook!;
                              pushCook(c.cookId);
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
