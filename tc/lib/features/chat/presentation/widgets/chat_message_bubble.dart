import 'package:flutter/material.dart';

import 'chat_design_tokens.dart';

/// Visual role of the bubble in the unified chat system.
enum ChatBubbleTone {
  /// Current user (soft primary).
  outgoing,

  /// Other participant in a customer ↔ chef thread.
  incoming,

  /// Admin / support staff (soft tinted lane).
  support,
}

extension ChatBubbleToneX on ChatBubbleTone {
  (Color bg, Color fg) get colors => switch (this) {
        ChatBubbleTone.outgoing => (
            ChatDesignTokens.bubbleOutgoingBg,
            ChatDesignTokens.bubbleOutgoingFg,
          ),
        ChatBubbleTone.incoming => (
            ChatDesignTokens.bubbleIncomingBg,
            ChatDesignTokens.bubbleIncomingFg,
          ),
        ChatBubbleTone.support => (
            ChatDesignTokens.bubbleSupportBg,
            ChatDesignTokens.bubbleSupportFg,
          ),
      };
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.tone,
    this.alignEnd = false,
  });

  final String text;
  final ChatBubbleTone tone;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors;
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: ChatDesignTokens.bubblePadding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ChatDesignTokens.bubbleRadius),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: fg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
