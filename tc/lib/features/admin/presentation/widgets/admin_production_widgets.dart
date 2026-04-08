import 'package:flutter/material.dart';

import 'admin_chart_shell.dart';
import 'admin_design_system_widgets.dart';
import 'admin_insight_card.dart';

/// Production naming aliases (spec: StatCard, RoleBadge, …).
typedef StatCard = AdminStatCard;
typedef ChartCard = AdminChartShell;
typedef RoleBadge = AdminRoleBadge;
typedef AccountStateBadge = CookAccountStateBadge;
typedef MessageSenderBadge = AdminMessageSenderChip;
typedef SectionHeader = AdminSectionHeader;
typedef InsightCard = AdminInsightCard;

/// Attention row with optional navigation.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    this.onTap,
    this.subtitle,
  });

  final String title;
  final int count;
  final IconData icon;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (count <= 0) return const SizedBox.shrink();
    final radius = BorderRadius.circular(AdminPanelTokens.cardRadiusLarge);
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminPanelTokens.space12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            decoration: AdminPanelTokens.surfaceCard(context, scheme),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AdminPanelTokens.space16,
                vertical: AdminPanelTokens.space12,
              ),
              minVerticalPadding: AdminPanelTokens.space12,
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer.withValues(alpha: 0.45),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2),
              ),
              subtitle: subtitle != null
                  ? Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.2),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: scheme.onSurface,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable data inside a titled card.
class DataTableCard extends StatelessWidget {
  const DataTableCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdminChartShell(
      title: title,
      subtitle: subtitle,
      minHeight: 0,
      child: child,
    );
  }
}
