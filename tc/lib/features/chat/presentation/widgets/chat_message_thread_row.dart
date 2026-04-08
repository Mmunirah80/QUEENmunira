import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';
import 'chat_design_tokens.dart';
import 'chat_message_bubble.dart';
import 'chat_message_role_label.dart';

/// Optimistic send state for messages not yet confirmed by the server.
enum ChatOutgoingSendState {
  none,
  sending,
  failed,
}

/// Single message line: muted role label → bubble → timestamp / send status.
///
/// Used by customer, cook, and admin conversation screens for layout parity.
class ChatMessageThreadRow extends StatelessWidget {
  const ChatMessageThreadRow({
    super.key,
    required this.roleLabel,
    required this.tone,
    required this.alignEnd,
    required this.text,
    required this.timeLabel,
    this.sendState = ChatOutgoingSendState.none,
    this.onRetryFailed,
  });

  final String roleLabel;
  final ChatBubbleTone tone;
  final bool alignEnd;
  final String text;
  final String timeLabel;
  final ChatOutgoingSendState sendState;
  final VoidCallback? onRetryFailed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ChatDesignTokens.messageSpacing),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatMessageRoleLabel(text: roleLabel, alignEnd: alignEnd),
          ChatMessageBubble(
            text: text,
            tone: tone,
            alignEnd: alignEnd,
          ),
          const SizedBox(height: 3),
          Align(
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeLabel, style: ChatDesignTokens.timeStyle),
                if (sendState == ChatOutgoingSendState.sending) ...[
                  const SizedBox(width: 6),
                  const Text('sending...', style: ChatDesignTokens.timeStyle),
                ],
                if (sendState == ChatOutgoingSendState.failed) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onRetryFailed,
                    child: const Text(
                      'failed — retry',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesignSystem.errorRed,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
