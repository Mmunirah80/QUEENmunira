import 'package:flutter/material.dart';

import 'admin_design_system_widgets.dart';

/// Single headline metric for dashboard smart insights (real data only).
class AdminInsightCard extends StatelessWidget {
  const AdminInsightCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AdminPanelTokens.cardRadius);
    final inner = Padding(
      padding: const EdgeInsets.all(AdminPanelTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AdminPanelTokens.space8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: AdminPanelTokens.space8),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
    final shell = SizedBox(
      width: 148,
      child: DecoratedBox(
        decoration: AdminPanelTokens.surfaceCard(context, scheme),
        child: inner,
      ),
    );
    if (onTap == null) return shell;
    return SizedBox(
      width: 148,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            decoration: AdminPanelTokens.surfaceCard(context, scheme),
            child: inner,
          ),
        ),
      ),
    );
  }
}
