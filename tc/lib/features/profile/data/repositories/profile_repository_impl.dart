import '../../domain/entities/cook_profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_mock_datasource.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/cook_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({
    ProfileRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? ProfileMockDataSource();

  @override
  Future<CookProfileEntity> getProfile() async {
    try {
      final profile = await remoteDataSource.getProfile();
      return profile;
    } catch (e) {
      throw Exception('Failed to get profile: ${e.toString()}');
    }
  }

  @override
  Future<CookProfileEntity> updateProfile(CookProfileEntity profile) async {
    try {
      final profileModel = CookProfileModel(
        id: profile.id,
        name: profile.name,
        email: profile.email,
        phone: profile.phone,
        profileImageUrl: profile.profileImageUrl,
        bio: profile.bio,
        rating: profile.rating,
        totalOrders: profile.totalOrders,
        totalReviews: profile.totalReviews,
        isVerified: profile.isVerified,
        joinedDate: profile.joinedDate,
      );
      final updatedProfile = await remoteDataSource.updateProfile(profileModel);
      return updatedProfile;
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }
}
