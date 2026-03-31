import '../../domain/entities/home_stats_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_mock_datasource.dart';
import '../datasources/home_remote_datasource.dart';
import '../models/home_stats_model.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remoteDataSource;

  HomeRepositoryImpl({
    HomeRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? HomeMockDataSource();

  @override
  Future<HomeStatsEntity> getHomeStats() async {
    try {
      final statsModel = await remoteDataSource.getHomeStats();
      return statsModel;
    } catch (e) {
      throw Exception('Failed to get home stats: ${e.toString()}');
    }
  }

  @override
  Future<void> updateDailyCapacity(int capacity) async {
    try {
      await remoteDataSource.updateDailyCapacity(capacity);
    } catch (e) {
      throw Exception('Failed to update capacity: ${e.toString()}');
    }
  }

  @override
  Future<void> toggleOnlineStatus(bool isOnline) async {
    try {
      await remoteDataSource.toggleOnlineStatus(isOnline);
    } catch (e) {
      throw Exception('Failed to toggle online status: ${e.toString()}');
    }
  }

  @override
  Future<void> updateWorkingHours(String? start, String? end) async {
    try {
      await remoteDataSource.updateWorkingHours(start, end);
    } catch (e) {
      throw Exception('Failed to update working hours: ${e.toString()}');
    }
  }
}
