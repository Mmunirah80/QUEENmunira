import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_monitor_banner.dart';

void main() {
  testWidgets('shows Monitoring conversation copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMonitorBanner(),
        ),
      ),
    );
    expect(find.text('Monitoring conversation'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
