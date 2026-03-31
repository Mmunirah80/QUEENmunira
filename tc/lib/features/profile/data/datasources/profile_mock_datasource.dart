import '../../../../core/constants/app_constants.dart';
import '../models/cook_profile_model.dart';
import 'profile_remote_datasource.dart';

class ProfileMockDataSource implements ProfileRemoteDataSource {
  CookProfileModel _profile = const CookProfileModel(
    id: 'cook_1',
    name: 'My Cook Name',
    email: 'cook@example.com',
    phone: '+1234567890',
    bio: 'Passionate home cook specializing in Middle Eastern cuisine',
    rating: 4.8,
    totalOrders: 156,
    totalReviews: 89,
    isVerified: true,
    joinedDate: null,
  );

  @override
  Future<CookProfileModel> getProfile() async {
    await Future.delayed(AppConstants.mockDelay);
    return _profile;
  }

  @override
  Future<CookProfileModel> updateProfile(CookProfileModel profile) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _profile = profile;
    return _profile;
  }
}
