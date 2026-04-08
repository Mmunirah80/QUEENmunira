import 'package:flutter/material.dart';

import 'chat_design_tokens.dart';

/// Small muted label shown **above** the bubble (participant name / role).
class ChatMessageRoleLabel extends StatelessWidget {
  const ChatMessageRoleLabel({
    super.key,
    required this.text,
    this.alignEnd = false,
  });

  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          t,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ChatDesignTokens.roleLabelStyle,
        ),
      ),
    );
  }
}
