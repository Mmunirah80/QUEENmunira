import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/naham_screen_header.dart';
import '../providers/admin_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalOrders = ref.watch(totalOrdersCountProvider);
    final thisMonth = ref.watch(thisMonthOrdersCountProvider);
    final last7Revenue = ref.watch(last7DaysRevenueProvider);
    final mostDishes = ref.watch(mostOrderedDishesProvider);
    final mostChefs = ref.watch(mostActiveChefsProvider);
    final peakHours = ref.watch(peakOrderHoursProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: NahamScreenHeader(title: 'التحليلات والتقارير')),
          SliverPadding(
            padding: const EdgeInsets.all(AppDesignSystem.space24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SummaryCards(totalOrders: totalOrders, thisMonth: thisMonth),
                const SizedBox(height: 24),
                Text('إيرادات آخر 7 أيام (ر.س)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                last7Revenue.when(
                  data: (values) => _RevenueChart(values: values),
                  loading: () => const SizedBox(height: 200, child: Center(child: LoadingWidget())),
                  error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('خطأ: $e'))),
                ),
                const SizedBox(height: 24),
                Text('أكثر الأطباق طلباً', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                mostDishes.when(
                  data: (list) => list.isEmpty
                      ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا بيانات')))
                      : Column(children: list.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value}'))).toList()),
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('خطأ: $e', style: const TextStyle(color: AppDesignSystem.errorRed)),
                ),
                const SizedBox(height: 24),
                Text('أكثر الطباخين نشاطاً', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                mostChefs.when(
                  data: (list) => list.isEmpty
                      ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا بيانات')))
                      : Column(children: list.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value} طلب'))).toList()),
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('خطأ: $e', style: const TextStyle(color: AppDesignSystem.errorRed)),
                ),
                const SizedBox(height: 24),
                Text('ساعات الذروة للطلبات', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                peakHours.when(
                  data: (byHour) => _PeakHoursBar(byHour: byHour),
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('خطأ: $e', style: const TextStyle(color: AppDesignSystem.errorRed)),
                ),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AsyncValue<int> totalOrders;
  final AsyncValue<int> thisMonth;

  const _SummaryCards({required this.totalOrders, required this.thisMonth});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDesignSystem.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي الطلبات', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  totalOrders.when(
                    data: (v) => Text('$v', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    loading: () => const LoadingWidget(),
                    error: (_, __) => const Text('—'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDesignSystem.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('طلبات هذا الشهر', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  thisMonth.when(
                    data: (v) => Text('$v', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    loading: () => const LoadingWidget(),
                    error: (_, __) => const Text('—'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<double> values;

  const _RevenueChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxY = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final maxYAxis = maxY <= 0 ? 1.0 : (maxY * 1.2).ceilToDouble();
    const days = ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمعة'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.space24),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxYAxis,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt() >= 0 && value.toInt() < days.length ? days[value.toInt()] : '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (i) {
                final v = i < values.length ? values[i] : 0.0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: v,
                      color: i % 2 == 0 ? NahamTheme.primary : NahamTheme.secondary,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeakHoursBar extends StatelessWidget {
  final Map<int, int> byHour;

  const _PeakHoursBar({required this.byHour});

  @override
  Widget build(BuildContext context) {
    final maxCount = byHour.values.isEmpty ? 1 : byHour.values.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.space16),
        child: Column(
          children: List.generate(24, (i) {
            final count = byHour[i] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 32, child: Text('$i:00', style: Theme.of(context).textTheme.bodySmall)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: maxCount > 0 ? count / maxCount : 0,
                      backgroundColor: NahamTheme.cardBackground,
                      valueColor: const AlwaysStoppedAnimation<Color>(NahamTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
