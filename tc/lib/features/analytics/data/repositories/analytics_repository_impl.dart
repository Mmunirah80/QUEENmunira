import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_mock_datasource.dart';
import '../datasources/analytics_remote_datasource.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource remoteDataSource;

  AnalyticsRepositoryImpl({
    AnalyticsRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? AnalyticsMockDataSource();

  @override
  Future<AnalyticsEntity> getAnalytics() async {
    try {
      final analytics = await remoteDataSource.getAnalytics();
      return analytics;
    } catch (e) {
      throw Exception('Failed to get analytics: ${e.toString()}');
    }
  }
}
