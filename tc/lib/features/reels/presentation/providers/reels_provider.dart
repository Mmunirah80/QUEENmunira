import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/reels_repository_impl.dart';
import '../../domain/entities/reel_entity.dart';
import '../../domain/repositories/reels_repository.dart';

final reelsRepositoryProvider = Provider<ReelsRepository>((ref) {
  return ReelsRepositoryImpl();
});

final reelsProvider = FutureProvider<List<ReelEntity>>((ref) async {
  final repository = ref.watch(reelsRepositoryProvider);
  return await repository.getReels();
});

final reelsStreamProvider = StreamProvider<List<ReelEntity>>((ref) {
  final repository = ref.watch(reelsRepositoryProvider);
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  return repository.streamReels(currentUserId: userId);
});

final myReelsProvider = FutureProvider<List<ReelEntity>>((ref) async {
  final repository = ref.watch(reelsRepositoryProvider);
  return await repository.getMyReels();
});

final myReelsStreamProvider = StreamProvider.family<List<ReelEntity>, String>((ref, chefId) {
  final repository = ref.watch(reelsRepositoryProvider);
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  return repository.streamMyReels(chefId, currentUserId: userId);
});

final searchReelsByTagProvider = FutureProvider.family<List<ReelEntity>, String>((ref, tag) async {
  final repository = ref.watch(reelsRepositoryProvider);
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  return repository.searchReelsByTag(tag, currentUserId: userId);
});
