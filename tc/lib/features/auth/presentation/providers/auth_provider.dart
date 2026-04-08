import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/storage/auth_storage.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../data/chef_reg_draft_storage.dart';
import '../../data/datasources/chef_registration_datasource.dart';
import '../../data/models/chef_reg_draft.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/signup_usecase.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final signupUseCaseProvider = Provider<SignupUseCase>((ref) {
  return SignupUseCase(ref.watch(authRepositoryProvider));
});

/// Role selected on role-selection screen; passed into login so user gets correct role.
final selectedRoleProvider = StateProvider<AppRole?>((ref) => null);

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  // Do not call notifier.dispose() in ref.onDispose — StateNotifierProvider disposes the notifier once.
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

/// Draft data from chef registration step 1 (account); used by step 2 (documents).
final chefRegDraftProvider = StateProvider<ChefRegDraft?>((ref) => null);

final chefRegistrationDataSourceProvider = Provider<ChefRegistrationDataSource>((ref) {
  return ChefRegistrationDataSource();
});

class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository repository;
  final Ref _ref;
  StreamSubscription<void>? _authSub;
  RealtimeChannel? _blockChannel;
  RealtimeChannel? _chefProfileChannel;

  AuthNotifier(this.repository, this._ref) : super(const AsyncValue.loading()) {
    _checkAuthStatus();
    _authSub = repository.watchAuthState().listen((_) async {
      try {
        final user = await repository.getCurrentUser();
        state = AsyncValue.data(user);
        _syncRealtimeChannels(user);
      } catch (e, st) {
        debugPrint('[AUTH] watchAuthState refresh failed: $e\n$st');
        state = const AsyncValue.data(null);
        _syncRealtimeChannels(null);
      }
    });
  }

  void _syncRealtimeChannels(UserEntity? user) {
    _blockChannel?.unsubscribe();
    _blockChannel = null;
    _chefProfileChannel?.unsubscribe();
    _chefProfileChannel = null;
    final uid = user?.id;
    if (uid == null || uid.isEmpty) return;
    final client = SupabaseConfig.client;

    _blockChannel = client.channel('profiles-block-$uid');
    _blockChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: uid,
      ),
      callback: (payload) async {
        // Refresh on any profiles row change (block, unblock, name, etc.).
        try {
          final u = await repository.getCurrentUser();
          state = AsyncValue.data(u);
        } catch (_) {}
      },
    );
    _blockChannel!.subscribe();

    if (user!.isChef) {
      _chefProfileChannel = client.channel('chef-profile-$uid');
      _chefProfileChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'chef_profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: uid,
        ),
        callback: (_) async {
          try {
            final u = await repository.getCurrentUser();
            state = AsyncValue.data(u);
          } catch (_) {}
        },
      );
      _chefProfileChannel!.subscribe();
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final user = await repository.getCurrentUser();
      state = AsyncValue.data(user);
      _syncRealtimeChannels(user);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      _syncRealtimeChannels(null);
    }
  }

  /// Refetch session user (e.g. after profile row changes).
  Future<void> refreshUser() async {
    try {
      final user = await repository.getCurrentUser();
      state = AsyncValue.data(user);
      _syncRealtimeChannels(user);
    } catch (_) {
      state = const AsyncValue.data(null);
      _syncRealtimeChannels(null);
    }
  }

  Future<void> login(String email, String password, [AppRole? role]) async {
    state = const AsyncValue.loading();
    try {
      final useCase = LoginUseCase(repository);
      final user = await useCase(email, password, role);
      state = AsyncValue.data(user);
      _syncRealtimeChannels(user);
      await AuthStorage.setLoggedIn(true);
    } catch (e, stackTrace) {
      // Keep router on AsyncData(null), not AsyncError — avoids redirect/error churn after a bad password.
      state = const AsyncValue.data(null);
      _syncRealtimeChannels(null);
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = SignupUseCase(repository);
      final user = await useCase(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );
      state = AsyncValue.data(user);
      _syncRealtimeChannels(user);
      await AuthStorage.setLoggedIn(true);
    } catch (e, stackTrace) {
      state = const AsyncValue.data(null);
      _syncRealtimeChannels(null);
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  Future<void> logout() async {
    try {
      _syncRealtimeChannels(null);
      await ChefRegDraftStorage.clear();
      _ref.read(chefRegDraftProvider.notifier).state = null;
      await repository.logout();
      await AuthStorage.setLoggedIn(false);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> resetPassword(String email) async {
    await repository.resetPassword(email);
  }

  /// Sets current user (e.g. after chef registration); marks as logged in.
  Future<void> setUser(UserEntity user) async {
    state = AsyncValue.data(user);
    _syncRealtimeChannels(user);
    await AuthStorage.setLoggedIn(true);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _blockChannel?.unsubscribe();
    _chefProfileChannel?.unsubscribe();
    super.dispose();
  }
}
