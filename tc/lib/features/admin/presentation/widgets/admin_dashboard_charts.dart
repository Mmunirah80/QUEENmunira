import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/models/admin_dashboard_stats.dart';
import 'admin_design_system_widgets.dart';

/// Applications: pending vs approved vs rejected (document pipeline).
class AdminApplicationsBarChart extends StatelessWidget {
  const AdminApplicationsBarChart({super.key, required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = [
      ('Pending', stats.pendingApplications.toDouble(), scheme.tertiary),
      ('Approved', stats.documentsApprovedTotal.toDouble(), scheme.primary),
      ('Rejected', stats.documentsRejectedTotal.toDouble(), scheme.error),
    ];
    final maxY = groups.fold<double>(1, (m, e) => m > e.$2 ? m : e.$2) * 1.15;

    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 8),
      child: BarChart(
        BarChartData(
          maxY: maxY < 4 ? 4 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY < 4 ? 1 : null,
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
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (i, m) {
                  final idx = i.toInt();
                  if (idx < 0 || idx >= groups.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      groups[idx].$1,
                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < groups.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: groups[i].$2,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    color: groups[i].$3,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Order pipeline distribution (recent sample buckets).
class AdminOrdersPieChart extends StatelessWidget {
  const AdminOrdersPieChart({super.key, required this.pipeline});

  final Map<String, int> pipeline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = [
      ('Awaiting', pipeline['awaiting'] ?? 0),
      ('Accepted', pipeline['accepted'] ?? 0),
      ('Preparing', pipeline['preparing'] ?? 0),
      ('Ready', pipeline['ready'] ?? 0),
      ('Done', pipeline['completed'] ?? 0),
      ('Cancelled', pipeline['cancelled'] ?? 0),
    ].where((e) => e.$2 > 0).toList();
    final total = entries.fold<int>(0, (s, e) => s + e.$2);
    if (total == 0) {
      return Center(
        child: Text(
          'No recent orders in sample',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    final colors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      Colors.teal,
      Colors.deepOrange,
      scheme.outline,
    ];

    var i = 0;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 1,
              centerSpaceRadius: 28,
              sections: [
                for (final e in entries)
                  PieChartSectionData(
                    value: e.$2.toDouble(),
                    title: '${(e.$2 / total * 100).round()}%',
                    radius: 44,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    color: colors[i++ % colors.length],
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
              for (var j = 0; j < entries.length; j++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[j % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${entries[j].$1} · ${entries[j].$2}',
                          style: const TextStyle(fontSize: 11),
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

/// Role distribution snapshot (not a time series).
class AdminUserRolesBarChart extends StatelessWidget {
  const AdminUserRolesBarChart({super.key, required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = [
      ('Customers', stats.totalCustomers.toDouble(), AdminUiColors.customerSurface),
      ('Cooks', stats.totalCooks.toDouble(), AdminUiColors.cookOnSurface),
      ('Admins', stats.totalAdmins.toDouble(), AdminUiColors.adminOnSurface),
    ];
    final maxY = groups.fold<double>(1, (m, e) => m > e.$2 ? m : e.$2) * 1.1;

    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 8),
      child: BarChart(
        BarChartData(
          maxY: maxY < 5 ? 5 : maxY,
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
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (i, m) {
                  final idx = i.toInt();
                  if (idx < 0 || idx >= groups.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      groups[idx].$1,
                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < groups.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: groups[i].$2,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    color: groups[i].$3,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Account status: blocked/frozen slice vs active (approximation from dashboard counts).
class AdminAccountStatusPieChart extends StatelessWidget {
  const AdminAccountStatusPieChart({super.key, required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final restricted = stats.frozenAccounts;
    final active = (stats.totalUsers - restricted).clamp(0, stats.totalUsers);
    if (stats.totalUsers == 0) {
      return Center(
        child: Text(
          'No user data',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    final sections = <PieChartSectionData>[];
    if (active > 0) {
      sections.add(
        PieChartSectionData(
          value: active.toDouble(),
          title: 'Active',
          radius: 46,
          color: scheme.primary,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }
    if (restricted > 0) {
      sections.add(
        PieChartSectionData(
          value: restricted.toDouble(),
          title: 'Restricted',
          radius: 46,
          color: scheme.error,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }
    if (sections.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 32,
              sections: sections,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendRow(scheme.primary, 'Active accounts', '$active'),
              const SizedBox(height: 8),
              _legendRow(scheme.error, 'Blocked / frozen', '$restricted'),
              const SizedBox(height: 8),
              Text(
                'Based on profiles and cook freeze rules.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _legendRow(Color c, String label, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
