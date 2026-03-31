import '../models/home_stats_model.dart';

abstract class HomeRemoteDataSource {
  Future<HomeStatsModel> getHomeStats();
  Future<void> updateDailyCapacity(int capacity);
  Future<void> toggleOnlineStatus(bool isOnline);
  Future<void> updateWorkingHours(String? start, String? end);
}
