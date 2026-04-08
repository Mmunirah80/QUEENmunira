import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';
import 'chat_design_tokens.dart';

/// Unified composer — only mount when the user is allowed to send.
class NahamChatInputBar extends StatelessWidget {
  const NahamChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.sending = false,
    this.enabled = true,
    this.hintText = 'Type a message...',
    this.surfaceColor = AppDesignSystem.cardWhite,
    this.fillColor = AppDesignSystem.backgroundOffWhite,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  /// When false, field and send are disabled (e.g. read-only policy); prefer hiding the bar entirely when possible.
  final bool enabled;
  final String hintText;
  final Color surfaceColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: surfaceColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ChatDesignTokens.listHorizontalPadding,
          10,
          ChatDesignTokens.listHorizontalPadding,
          bottom + 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled && !sending,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: AppDesignSystem.textSecondary,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: fillColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: (!enabled || sending) ? null : onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (!enabled || sending)
                      ? AppDesignSystem.primary.withValues(alpha: 0.55)
                      : AppDesignSystem.primary,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
