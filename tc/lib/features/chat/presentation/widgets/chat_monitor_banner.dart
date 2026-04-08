import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';
import 'chat_design_tokens.dart';

/// Shown when an admin is viewing a thread in read-only monitor mode.
class ChatMonitorBanner extends StatelessWidget {
  const ChatMonitorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignSystem.primaryLight.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ChatDesignTokens.listHorizontalPadding,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 18,
              color: AppDesignSystem.primaryDark.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Monitoring conversation',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.primaryDark.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
