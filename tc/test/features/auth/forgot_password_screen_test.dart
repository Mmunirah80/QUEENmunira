import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naham_cook_app/features/auth/domain/entities/user_entity.dart';
import 'package:naham_cook_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:naham_cook_app/features/auth/screens/forgot_password_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.onResetPassword,
  });

  Future<void> Function(String email)? onResetPassword;
  int resetPasswordCalls = 0;

  @override
  Future<UserEntity?> getCurrentUser() => SynchronousFuture<UserEntity?>(null);

  @override
  Future<UserEntity> login(String email, String password, [AppRole? role]) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> resetPassword(String email) async {
    resetPasswordCalls++;
    if (onResetPassword != null) {
      await onResetPassword!(email);
    }
  }

  @override
  Future<UserEntity> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) =>
      throw UnimplementedError();

  @override
  Stream<void> watchAuthState() => const Stream<void>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Intentionally no Supabase.initialize — avoids global auth events racing AuthNotifier.dispose in tests.
  });

  testWidgets('1) empty email shows validation, does not call repository', (tester) async {
    final fake = _FakeAuthRepository(onResetPassword: (_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(fake.resetPasswordCalls, 0);
  });

  testWidgets('2) invalid email format shows validation, does not call repository', (tester) async {
    final fake = _FakeAuthRepository(onResetPassword: (_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email'), findsOneWidget);
    expect(fake.resetPasswordCalls, 0);
  });

  testWidgets('3) valid email calls resetPassword and shows success panel', (tester) async {
    final fake = _FakeAuthRepository(
      onResetPassword: (_) async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(fake.resetPasswordCalls, 1);
    expect(find.textContaining('Check your email'), findsOneWidget);

    // Let AuthNotifier async work finish before scope dispose (avoids late state updates).
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('4) repository failure shows error snackbar', (tester) async {
    final fake = _FakeAuthRepository(
      onResetPassword: (_) async {
        throw Exception('Simulated network failure');
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pump(); // start async
    await tester.pump(const Duration(seconds: 1)); // SnackBar

    expect(fake.resetPasswordCalls, 1);
    // userFriendlyErrorMessage maps "network" in the exception to a fixed copy.
    expect(
      find.textContaining('Network problem'),
      findsOneWidget,
    );
  });
}
