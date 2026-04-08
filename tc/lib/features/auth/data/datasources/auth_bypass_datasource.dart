import '../../../../core/debug/debug_auth_bypass.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

/// Debug-only datasource: no [signInWithPassword], no Supabase session.
class AuthBypassDatasource implements AuthRemoteDataSource {
  @override
  Future<UserModel> login(String email, String password, [AppRole? role]) async {
    return DebugAuthBypass.userModel();
  }

  @override
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async {
    return DebugAuthBypass.userModel();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel?> getCurrentUser() async {
    return DebugAuthBypass.userModel();
  }
}
