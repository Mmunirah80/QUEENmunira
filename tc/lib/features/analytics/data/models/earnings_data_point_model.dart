import '../../domain/entities/analytics_entity.dart';

class EarningsDataPointModel extends EarningsDataPoint {
  const EarningsDataPointModel({
    required super.date,
    required super.earnings,
  });

  factory EarningsDataPointModel.fromJson(Map<String, dynamic> json) {
    return EarningsDataPointModel(
      date: DateTime.parse(json['date'] as String),
      earnings: (json['earnings'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'earnings': earnings,
    };
  }
}
