import '../models/cook_profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<CookProfileModel> getProfile();
  Future<CookProfileModel> updateProfile(CookProfileModel profile);
}
