import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_role_label.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_message_thread_row.dart';

void main() {
  testWidgets('column order: role label above bubble above time row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatMessageThreadRow(
              roleLabel: 'Um Noura Kitchen',
              tone: ChatBubbleTone.incoming,
              alignEnd: false,
              text: 'Hello',
              timeLabel: '12:00',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Um Noura Kitchen'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);

    final column = tester.widget<Column>(find.byType(Column).first);
    expect(column.children[0], isA<ChatMessageRoleLabel>());
    expect(column.children[1], isA<ChatMessageBubble>());
  });

  testWidgets('consecutive rows: different role labels both visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageThreadRow(
                roleLabel: 'Customer',
                tone: ChatBubbleTone.incoming,
                alignEnd: false,
                text: 'A',
                timeLabel: '1:00',
              ),
              ChatMessageThreadRow(
                roleLabel: 'Kitchen',
                tone: ChatBubbleTone.outgoing,
                alignEnd: true,
                text: 'B',
                timeLabel: '1:01',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('long message text is in bubble', (tester) async {
    final longText = 'Lorem ipsum dolor sit amet, ' * 20;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageThreadRow(
            roleLabel: 'X',
            tone: ChatBubbleTone.incoming,
            alignEnd: false,
            text: longText,
            timeLabel: '—',
          ),
        ),
      ),
    );
    expect(find.textContaining('Lorem ipsum'), findsOneWidget);
  });

  testWidgets('optimistic failed shows retry affordance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageThreadRow(
            roleLabel: 'You',
            tone: ChatBubbleTone.outgoing,
            alignEnd: true,
            text: 'oops',
            timeLabel: '12:00',
            sendState: ChatOutgoingSendState.failed,
            onRetryFailed: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('failed'), findsOneWidget);
  });
}
