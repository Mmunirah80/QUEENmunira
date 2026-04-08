import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';
import 'chat_design_tokens.dart';

/// Shown when the user can read the thread but must not send (blocked, suspended, monitor).
class ChatReadOnlyBanner extends StatelessWidget {
  const ChatReadOnlyBanner({
    super.key,
    required this.message,
    this.icon = Icons.lock_outline_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignSystem.warningOrange.withValues(alpha: 0.22),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ChatDesignTokens.listHorizontalPadding,
          vertical: 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppDesignSystem.textPrimary.withValues(alpha: 0.85)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: AppDesignSystem.textPrimary.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
