import '../entities/analytics_entity.dart';

abstract class AnalyticsRepository {
  Future<AnalyticsEntity> getAnalytics();
}
