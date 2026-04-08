import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_design_tokens.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_role_label.dart';

void main() {
  testWidgets('role label uses muted small style', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageRoleLabel(text: 'Support'),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('Support'));
    expect(text.style?.fontSize, ChatDesignTokens.roleLabelStyle.fontSize);
    expect(text.style?.color, ChatDesignTokens.roleLabelStyle.color);
    expect(text.style?.fontWeight, ChatDesignTokens.roleLabelStyle.fontWeight);
  });

  testWidgets('empty label yields no text widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageRoleLabel(text: '   '),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });
}
