import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naham_cook_app/core/supabase/supabase_config.dart';
import 'package:naham_cook_app/features/admin/data/datasources/admin_supabase_datasource.dart';
import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/admin/screens/admin_users_hub_screen.dart';
import 'package:naham_cook_app/features/auth/domain/entities/user_entity.dart';
import 'package:naham_cook_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';

class _FakeAuthRepo implements AuthRepository {
  static const UserEntity admin = UserEntity(
    id: 'e0a00001-0000-4000-8a00-00000000a001',
    email: 'qa.admin@naham.qa.demo',
    name: 'QA Admin',
    role: AppRole.admin,
  );

  @override
  Future<UserEntity?> getCurrentUser() async => admin;

  @override
  Stream<void> watchAuthState() => const Stream.empty();

  @override
  Future<void> logout() async {}

  @override
  Future<UserEntity> login(String email, String password, [AppRole? role]) async => admin;

  @override
  Future<UserEntity> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async =>
      admin;

  @override
  Future<void> resetPassword(String email) async {}
}

class _FakeAdminDatasource extends AdminSupabaseDatasource {
  @override
  Future<List<Map<String, dynamic>>> fetchInspectionCallsForAdmin({int limit = 40}) async => const [];
}

class _SilentPendingDocs extends AdminPendingCookDocumentsNotifier {
  _SilentPendingDocs(Ref r) : super(r) {
    state = const AdminPendingDocsState(initialLoading: false, hasMore: false);
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
    } catch (_) {}
  });

  testWidgets('Directory tab is index 0; Kitchen inspection is index 1; provider syncs', (tester) async {
    WidgetRef? refHolder;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => _FakeAuthRepo()),
          adminSupabaseDatasourceProvider.overrideWith((ref) => _FakeAdminDatasource()),
          adminProfilesListProvider.overrideWith((ref) async => const <Map<String, dynamic>>[]),
          adminPendingCookDocumentsNotifierProvider.overrideWith((ref) => _SilentPendingDocs(ref)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            refHolder = ref;
            return MaterialApp(
              theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
              home: const AdminUsersHubScreen(),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    final hubTabBar = tester.widget<TabBar>(find.byKey(const ValueKey<String>('adminUsersHubTabBar')));
    expect(hubTabBar.controller!.index, 0);
    expect(refHolder!.read(adminUsersHubTabProvider), 0);
    expect(find.textContaining('Name, phone, or kitchen'), findsOneWidget);

    await tester.tap(find.text('Kitchen inspection'));
    await tester.pumpAndSettle();

    expect(hubTabBar.controller!.index, 1);
    expect(refHolder!.read(adminUsersHubTabProvider), 1);
    expect(find.text('Application queue'), findsOneWidget);

    await tester.tap(find.text('Directory'));
    await tester.pumpAndSettle();

    expect(hubTabBar.controller!.index, 0);
    expect(refHolder!.read(adminUsersHubTabProvider), 0);
    expect(find.textContaining('Name, phone, or kitchen'), findsOneWidget);
  });
}
