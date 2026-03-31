import '../../domain/entities/analytics_entity.dart';
import 'earnings_data_point_model.dart';

class AnalyticsModel extends AnalyticsEntity {
  const AnalyticsModel({
    required super.earningsData,
    required super.totalEarnings,
    required super.monthlyEarnings,
    required super.totalOrders,
    required super.completedOrders,
    required super.averageOrderValue,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsModel(
      earningsData: (json['earningsData'] as List)
          .map((e) => EarningsDataPointModel.fromJson(e as Map<String, dynamic>))
          .toList()
          .cast<EarningsDataPoint>(),
      totalEarnings: (json['totalEarnings'] as num).toDouble(),
      monthlyEarnings: (json['monthlyEarnings'] as num).toDouble(),
      totalOrders: json['totalOrders'] as int,
      completedOrders: json['completedOrders'] as int,
      averageOrderValue: (json['averageOrderValue'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'earningsData': earningsData
          .map((e) => (e as EarningsDataPointModel).toJson())
          .toList(),
      'totalEarnings': totalEarnings,
      'monthlyEarnings': monthlyEarnings,
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
      'averageOrderValue': averageOrderValue,
    };
  }
}
