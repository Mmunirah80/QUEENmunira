import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/models/admin_analytics_bundle.dart';

class AdminOrdersByDayLineChart extends StatelessWidget {
  const AdminOrdersByDayLineChart({super.key, required this.points});

  final List<TimeSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value.toDouble()));
    }
    final maxY = spots.fold<double>(4, (m, s) => m > s.y ? m : s.y) * 1.1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: maxY < 4 ? 4 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 5).ceilToDouble().clamp(1, 30),
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final d = points[i].date;
                final short = d.length >= 10 ? d.substring(5, 10) : d;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: scheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminRevenueLineChart extends StatelessWidget {
  const AdminRevenueLineChart({super.key, required this.points});

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].amount));
    }
    final maxY = spots.fold<double>(1, (m, s) => m > s.y ? m : s.y) * 1.1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: maxY < 10 ? 10 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 5).ceilToDouble().clamp(1, 30),
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final d = points[i].date;
                final short = d.length >= 10 ? d.substring(5, 10) : d;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: scheme.tertiary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.tertiary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMonthlyOrdersBarChart extends StatelessWidget {
  const AdminMonthlyOrdersBarChart({super.key, required this.months});

  final List<NamedCount> months;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (months.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    final maxY = months.fold<double>(1, (m, e) => m > e.count ? m : e.count.toDouble()) * 1.15;

    return BarChart(
      BarChartData(
        maxY: maxY < 4 ? 4 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (i, m) {
                final idx = i.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    months[idx].name,
                    style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: months[i].count.toDouble(),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: scheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class AdminPeakHoursBarChart extends StatelessWidget {
  const AdminPeakHoursBarChart({super.key, required this.hours});

  final List<HourCount> hours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (hours.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    final sorted = [...hours]..sort((a, b) => a.hour.compareTo(b.hour));
    final maxY = sorted.fold<double>(1, (m, e) => m > e.count ? m : e.count.toDouble()) * 1.1;

    return BarChart(
      BarChartData(
        maxY: maxY < 4 ? 4 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (i, m) {
                final idx = i.toInt();
                if (idx < 0 || idx >= sorted.length) return const SizedBox.shrink();
                return Text(
                  '${sorted[idx].hour}h',
                  style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < sorted.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: sorted[i].count.toDouble(),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  color: scheme.secondary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class AdminApplicationPieChart extends StatelessWidget {
  const AdminApplicationPieChart({super.key, required this.pie});

  final Map<String, int> pie;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (pie.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    final entries = pie.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final colors = [scheme.primary, scheme.tertiary, scheme.secondary, scheme.error, scheme.outline];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    title: '${((entries[i].value / total) * 100).round()}%',
                    radius: 40,
                    color: colors[i % colors.length],
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${entries[i].key} · ${entries[i].value}',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminUserSignupLineChart extends StatelessWidget {
  const AdminUserSignupLineChart({super.key, required this.points});

  final List<TimeSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    return AdminOrdersByDayLineChart(
      points: points,
    );
  }
}
