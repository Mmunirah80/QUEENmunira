import 'dart:math';

import '../../../../core/constants/app_constants.dart';
import '../models/analytics_model.dart';
import '../models/earnings_data_point_model.dart';
import 'analytics_remote_datasource.dart';

class AnalyticsMockDataSource implements AnalyticsRemoteDataSource {
  @override
  Future<AnalyticsModel> getAnalytics() async {
    await Future.delayed(AppConstants.mockDelay);

    final random = Random();
    final List<EarningsDataPointModel> earningsData = List.generate(
      7,
      (int index) => EarningsDataPointModel(
        date: DateTime.now().subtract(Duration(days: 6 - index)),
        earnings: (random.nextDouble() * 500 + 100).roundToDouble(),
      ),
    );

    final totalEarnings = earningsData.fold<double>(
      0,
      (sum, point) => sum + point.earnings,
    );

    return AnalyticsModel(
      earningsData: earningsData,
      totalEarnings: totalEarnings,
      monthlyEarnings: totalEarnings * 4.3, // Approximate monthly
      totalOrders: 156,
      completedOrders: 142,
      averageOrderValue: totalEarnings / 142,
    );
  }
}
