import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/cook_profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

final profileProvider = FutureProvider<CookProfileEntity>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return await repository.getProfile();
});
