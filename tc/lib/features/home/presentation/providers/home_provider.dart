import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/home_repository_impl.dart';
import '../../domain/entities/home_stats_entity.dart';
import '../../domain/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl();
});

final homeStatsProvider = FutureProvider<HomeStatsEntity>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return await repository.getHomeStats();
});

final dailyCapacityProvider = StateNotifierProvider<DailyCapacityNotifier, int>((ref) {
  return DailyCapacityNotifier(ref.watch(homeRepositoryProvider));
});

final isOnlineProvider = StateNotifierProvider<IsOnlineNotifier, bool>((ref) {
  return IsOnlineNotifier(ref.watch(homeRepositoryProvider));
});

class DailyCapacityNotifier extends StateNotifier<int> {
  final HomeRepository repository;
  DailyCapacityNotifier(this.repository) : super(50);

  Future<void> updateCapacity(int capacity) async {
    await repository.updateDailyCapacity(capacity);
    state = capacity;
  }
}

class IsOnlineNotifier extends StateNotifier<bool> {
  final HomeRepository repository;
  IsOnlineNotifier(this.repository) : super(false);

  Future<void> toggle() async {
    final newStatus = !state;
    await repository.toggleOnlineStatus(newStatus);
    state = newStatus;
  }
}
