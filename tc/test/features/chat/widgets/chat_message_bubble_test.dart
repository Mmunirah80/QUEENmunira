import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_design_tokens.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_bubble.dart';

void main() {
  group('ChatMessageBubble tones', () {
    Future<Color> pumpAndReadBg(WidgetTester tester, ChatBubbleTone tone) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              text: 'x',
              tone: tone,
              alignEnd: false,
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ChatMessageBubble),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      return decoration.color!;
    }

    testWidgets('outgoing uses sender / primary-wash background', (tester) async {
      final bg = await pumpAndReadBg(tester, ChatBubbleTone.outgoing);
      expect(bg, ChatDesignTokens.bubbleOutgoingBg);
    });

    testWidgets('incoming uses neutral background', (tester) async {
      final bg = await pumpAndReadBg(tester, ChatBubbleTone.incoming);
      expect(bg, ChatDesignTokens.bubbleIncomingBg);
    });

    testWidgets('support uses admin-tinted background', (tester) async {
      final bg = await pumpAndReadBg(tester, ChatBubbleTone.support);
      expect(bg, ChatDesignTokens.bubbleSupportBg);
    });
  });
}
