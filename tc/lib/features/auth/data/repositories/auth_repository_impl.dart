import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_supabase_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({
    AuthRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? AuthSupabaseDatasource();

  @override
  Future<UserEntity> login(String email, String password, [AppRole? role]) async {
    try {
      return await remoteDataSource.login(email, password, role);
    } catch (e, st) {
      debugPrint('[Auth] Login error: $e');
      debugPrint('[Auth] StackTrace: $st');
      throw Exception(_sanitize(e));
    }
  }

  @override
  Future<UserEntity> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async {
    try {
      return await remoteDataSource.signup(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );
    } catch (e, st) {
      debugPrint('[Auth] Signup error: $e');
      debugPrint('[Auth] StackTrace: $st');
      throw Exception(_sanitize(e));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await remoteDataSource.logout();
    } catch (e) {
      throw Exception(_sanitize(e));
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      return await remoteDataSource.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<void> watchAuthState() {
    if (remoteDataSource is AuthSupabaseDatasource) {
      return (remoteDataSource as AuthSupabaseDatasource)
          .watchAuthState()
          .map((_) => null);
    }
    return Stream<void>.empty();
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      if (remoteDataSource is AuthSupabaseDatasource) {
        await (remoteDataSource as AuthSupabaseDatasource).resetPassword(email);
      } else {
        throw UnimplementedError('Reset password requires Supabase auth');
      }
    } catch (e) {
      throw Exception(_sanitize(e));
    }
  }

  String _sanitize(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('user-not-found') ||
        msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email already registered') ||
        msg.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('weak password') || msg.contains('weak-password')) {
      return 'Password is too weak (use at least 6 characters).';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection.';
    }
    if (msg.contains('rate limit') || msg.contains('rate_limit') || msg.contains('email rate limit') || msg.contains('429')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (msg.contains('infinite recursion') && msg.contains('profiles')) {
      return 'Server configuration error (profiles). Please try again later or contact support.';
    }
    if (msg.contains('account suspended') || msg.contains('suspended')) {
      return 'Account suspended. Contact support if you believe this is a mistake.';
    }
    if (e is AuthException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }
}
