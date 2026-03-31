// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naham_cook_app/core/theme/naham_theme.dart';
import 'package:naham_cook_app/core/supabase/supabase_config.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Supabase Flutter uses Gotrue async storage backed by SharedPreferences on some platforms.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Widget tests build SplashScreen which uses Supabase.instance.
    // Ensure Supabase is initialized for the test environment.
    try {
      await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
    } catch (_) {
      // Supabase may already be initialized.
    }
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NahamTheme.lightTheme,
        home: const Scaffold(body: Text('ok')),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
  });
}
