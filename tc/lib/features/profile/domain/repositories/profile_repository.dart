import '../entities/cook_profile_entity.dart';

abstract class ProfileRepository {
  Future<CookProfileEntity> getProfile();
  Future<CookProfileEntity> updateProfile(CookProfileEntity profile);
}
