/// Chef dashboard metrics for orders whose `created_at` falls in the **device local**
/// calendar day (bounds converted to UTC for the query). Not “completed during today”
/// unless the order was also placed that day.
class ChefTodayStats {
  const ChefTodayStats({
    required this.completedRevenueToday,
    required this.completedOrdersToday,
    required this.inKitchenCountToday,
    required this.pipelineOrderValueToday,
  });

  /// Sum of `total_amount` for orders **completed** in this local-day window.
  final double completedRevenueToday;

  /// Count of orders **completed** in this local-day window.
  final int completedOrdersToday;

  /// Count of in-kitchen orders in this local-day window.
  final int inKitchenCountToday;

  /// Sum of `total_amount` for [inKitchenCountToday] rows (in-flight GMV).
  final double pipelineOrderValueToday;
}
