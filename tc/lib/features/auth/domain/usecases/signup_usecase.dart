import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignupUseCase {
  final AuthRepository repository;

  SignupUseCase(this.repository);

  Future<UserEntity> call({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) {
    return repository.signup(
      email: email,
      password: password,
      name: name,
      phone: phone,
      role: role,
    );
  }
}
