import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

class AuthFirebaseDataSource implements AuthRemoteDataSource {
  @override
  Future<UserModel> login(String email, String password, [AppRole? role]) async {
    // Stub: Auth not implemented yet. Return a minimal guest user.
    return UserModel(
      id: '',
      email: email,
      name: 'Guest',
      phone: null,
      profileImageUrl: null,
      isVerified: false,
      role: role ?? AppRole.customer,
      chefApprovalStatus: null,
      rejectionReason: null,
    );
  }

  @override
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async {
    return UserModel(
      id: '',
      email: email,
      name: name,
      phone: phone,
      profileImageUrl: null,
      isVerified: false,
      role: role ?? AppRole.customer,
      chefApprovalStatus: null,
      rejectionReason: null,
    );
  }

  @override
  Future<void> logout() async {
    return;
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return null;
  }
}
