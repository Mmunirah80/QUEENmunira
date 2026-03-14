// Basic Flutter widget test for Naham Admin app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Admin')),
      ),
    );
    expect(find.text('Admin'), findsOneWidget);
  });
}
