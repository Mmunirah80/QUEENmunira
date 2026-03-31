import 'package:equatable/equatable.dart';

class AnalyticsEntity extends Equatable {
  final List<EarningsDataPoint> earningsData;
  final double totalEarnings;
  final double monthlyEarnings;
  final int totalOrders;
  final int completedOrders;
  final double averageOrderValue;

  const AnalyticsEntity({
    required this.earningsData,
    required this.totalEarnings,
    required this.monthlyEarnings,
    required this.totalOrders,
    required this.completedOrders,
    required this.averageOrderValue,
  });

  @override
  List<Object?> get props => [
        earningsData,
        totalEarnings,
        monthlyEarnings,
        totalOrders,
        completedOrders,
        averageOrderValue,
      ];
}

class EarningsDataPoint extends Equatable {
  final DateTime date;
  final double earnings;

  const EarningsDataPoint({
    required this.date,
    required this.earnings,
  });

  @override
  List<Object?> get props => [date, earnings];
}
