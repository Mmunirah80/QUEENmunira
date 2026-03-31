import '../entities/home_stats_entity.dart';

abstract class HomeRepository {
  Future<HomeStatsEntity> getHomeStats();
  Future<void> updateDailyCapacity(int capacity);
  Future<void> toggleOnlineStatus(bool isOnline);
  Future<void> updateWorkingHours(String? start, String? end);
}
