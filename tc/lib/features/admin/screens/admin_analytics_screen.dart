import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../data/models/admin_analytics_bundle.dart';
import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_chart_shell.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';
import '../presentation/widgets/admin_insights_fl_chart.dart';

/// Lightweight analytics (secondary route — not in main bottom navigation).
class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  final _cookSearch = TextEditingController();
  final _dishSearch = TextEditingController();

  @override
  void dispose() {
    _cookSearch.dispose();
    _dishSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final bundleAsync = ref.watch(adminAnalyticsBundleProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const AdminAppBarTitle(
          title: 'Analytics',
          subtitle: 'Trends & performance',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminAnalyticsBundleProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Icon(Icons.date_range_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Last 30 days',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          bundleAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('No data available', style: TextStyle(color: scheme.error)),
            data: (b) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminChartShell(
                    title: 'Orders (Last 30 days)',
                    subtitle: 'Per day',
                    child: AdminOrdersByDayLineChart(points: b.ordersByDay),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _cookSearch,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search top cooks by name or ID',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TopCooksSection(
                    bundle: b,
                    query: _cookSearch.text,
                    onOpenCook: (id) {
                      if (id.isEmpty) return;
                      context.push(RouteNames.adminUserDetail(id));
                    },
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _dishSearch,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search top dishes by name',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TopDishesSection(
                    bundle: b,
                    query: _dishSearch.text,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

bool _matchesQuery(String query, String name, String id) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final n = name.toLowerCase();
  final i = id.toLowerCase();
  return n.contains(q) || i.contains(q);
}

class _TopCooksSection extends StatelessWidget {
  const _TopCooksSection({
    required this.bundle,
    required this.query,
    required this.onOpenCook,
  });

  final AdminAnalyticsBundle bundle;
  final String query;
  final void Function(String cookId) onOpenCook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = bundle.topRequestedCooks
        .where((c) => _matchesQuery(query, c.name, c.cookId))
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Top Cooks',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.2,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Best performing cooks this period',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Text(
            bundle.topRequestedCooks.isEmpty ? 'No data' : 'No matching cooks',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          ...List.generate(filtered.length, (i) {
            final c = filtered[i];
            final rank = i + 1;
            return Padding(
              padding: EdgeInsets.only(bottom: i == filtered.length - 1 ? 0 : 10),
              child: Material(
                color: scheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: c.cookId.isNotEmpty ? () => onOpenCook(c.cookId) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name.isEmpty ? '—' : c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${c.orderCount} orders',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _TopDishesSection extends StatelessWidget {
  const _TopDishesSection({
    required this.bundle,
    required this.query,
  });

  final AdminAnalyticsBundle bundle;
  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = bundle.topSellingDishes
        .where((d) => _matchesQuery(query, d.dishName, ''))
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Top Dishes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.2,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Most ordered dishes this period',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Text(
            bundle.topSellingDishes.isEmpty ? 'No data' : 'No matching dishes',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          ...List.generate(filtered.length, (i) {
            final d = filtered[i];
            final rank = i + 1;
            return Padding(
              padding: EdgeInsets.only(bottom: i == filtered.length - 1 ? 0 : 10),
              child: Material(
                color: scheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.tertiary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: scheme.tertiary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.dishName.isEmpty ? '—' : d.dishName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${d.ordersCount} orders · ${d.quantitySold} sold',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
