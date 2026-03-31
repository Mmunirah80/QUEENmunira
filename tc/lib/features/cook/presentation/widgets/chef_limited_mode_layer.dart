import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';

/// Dims the main chef tab content when the account is pending approval or
/// suspended (e.g. rejected document). Chat + Profile stay fully interactive.
class ChefLimitedModeLayer extends StatelessWidget {
  const ChefLimitedModeLayer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Opacity(
            opacity: 0.38,
            child: child,
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: 0.04),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 40, color: AppDesignSystem.primary),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppDesignSystem.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use Chat (Support) for messages from the team. '
                            'Profile → Notifications for alerts. '
                            'Profile → Documents to upload files.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
