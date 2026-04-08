import 'package:flutter/material.dart';

import 'admin_design_system_widgets.dart';

/// Reusable card wrapper for dashboard / analytics charts.
class AdminChartShell extends StatelessWidget {
  const AdminChartShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.minHeight = 200,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AdminPanelTokens.space16),
      decoration: AdminPanelTokens.surfaceCard(context, scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, height: 1.25),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: AdminPanelTokens.space8),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ),
          const SizedBox(height: AdminPanelTokens.space12),
          if (minHeight > 0) SizedBox(height: minHeight, child: child) else child,
        ],
      ),
    );
  }
}
