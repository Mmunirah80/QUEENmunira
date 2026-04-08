import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/domain/chef_today_stats_aggregator.dart';

void main() {
  test('aggregateChefTodayStatsFromOrderRows sums completed vs in-kitchen pipeline', () {
    final stats = aggregateChefTodayStatsFromOrderRows([
      {'status': 'completed', 'total_amount': 40},
      {'status': 'completed', 'total_amount': 10},
      {'status': 'accepted', 'total_amount': 25},
      {'status': 'preparing', 'total_amount': 15},
      {'status': 'ready', 'total_amount': 5},
    ]);

    expect(stats.completedOrdersToday, 2);
    expect(stats.completedRevenueToday, 50);
    expect(stats.inKitchenCountToday, 3);
    expect(stats.pipelineOrderValueToday, 25 + 15 + 5);
  });

  test('string amounts parse to double', () {
    final stats = aggregateChefTodayStatsFromOrderRows([
      {'status': 'completed', 'total_amount': '12.5'},
    ]);
    expect(stats.completedRevenueToday, 12.5);
    expect(stats.completedOrdersToday, 1);
  });
}
