import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/naham_chat_input_bar.dart';

void main() {
  testWidgets('shows TextField and send affordance when enabled', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NahamChatInputBar(
            controller: ctrl,
            onSend: () {},
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('disables TextField when enabled is false', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NahamChatInputBar(
            controller: ctrl,
            onSend: () {},
            enabled: false,
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });
}
