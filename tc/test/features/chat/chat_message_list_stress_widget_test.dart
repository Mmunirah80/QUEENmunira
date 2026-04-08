import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_thread_row.dart';

/// Many rows + first/last spacing sanity (scroll + layout).
void main() {
  testWidgets('many messages: list scrolls and rows are findable', (tester) async {
    final rows = List.generate(
      40,
      (i) => ChatMessageThreadRow(
        roleLabel: i.isEven ? 'Customer' : 'Kitchen',
        tone: i.isEven ? ChatBubbleTone.incoming : ChatBubbleTone.outgoing,
        alignEnd: i.isOdd,
        text: 'Message $i',
        timeLabel: '9:${i.toString().padLeft(2, '0')}',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: rows),
          ),
        ),
      ),
    );

    expect(find.byType(ChatMessageThreadRow), findsNWidgets(40));
    expect(find.text('Message 0'), findsOneWidget);
    expect(find.text('Message 39'), findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
    await tester.pump();
    expect(find.text('Message 39'), findsOneWidget);
  });
}
