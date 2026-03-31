import '../entities/user_entity.dart';

export '../entities/user_entity.dart' show AppRole;

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password, [AppRole? role]);
  Future<UserEntity> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  });
  Future<void> logout();
  Future<UserEntity?> getCurrentUser();
  /// Stream of auth state changes (login, logout, token refresh). Emits when state changes.
  Stream<void> watchAuthState();
  Future<void> resetPassword(String email);
}
