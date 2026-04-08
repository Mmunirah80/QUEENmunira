import '../data/order_db_status.dart';
import 'entities/chef_today_stats.dart';

/// Pure aggregation for [ChefTodayStats] from `orders` rows (same rules as
/// [OrdersSupabaseDataSource.getTodayStats]).
ChefTodayStats aggregateChefTodayStatsFromOrderRows(
  Iterable<Map<String, dynamic>> rows,
) {
  var completedRev = 0.0;
  var completedCnt = 0;
  var kitchenCnt = 0;
  var pipelineVal = 0.0;
  for (final row in rows) {
    final st = row['status']?.toString();
    final amt = _toDouble(row['total_amount']);
    if (OrderDbStatus.isCompletedDbStatus(st)) {
      completedRev += amt;
      completedCnt++;
    }
    if (OrderDbStatus.isInKitchenDbStatus(st)) {
      kitchenCnt++;
      pipelineVal += amt;
    }
  }
  return ChefTodayStats(
    completedRevenueToday: completedRev,
    completedOrdersToday: completedCnt,
    inKitchenCountToday: kitchenCnt,
    pipelineOrderValueToday: pipelineVal,
  );
}

double _toDouble(dynamic x) {
  if (x == null) return 0;
  if (x is num) return x.toDouble();
  if (x is String) return double.tryParse(x) ?? 0;
  return 0;
}
