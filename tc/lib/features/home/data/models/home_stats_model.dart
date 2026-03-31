import '../../domain/entities/home_stats_entity.dart';

class HomeStatsModel extends HomeStatsEntity {
  const HomeStatsModel({
    required super.dailyCapacity,
    required super.currentOrders,
    required super.isOnline,
    super.workingHoursStart,
    super.workingHoursEnd,
  });

  factory HomeStatsModel.fromJson(Map<String, dynamic> json) {
    return HomeStatsModel(
      dailyCapacity: json['dailyCapacity'] as int,
      currentOrders: json['currentOrders'] as int,
      isOnline: json['isOnline'] as bool,
      workingHoursStart: json['workingHoursStart'] as String?,
      workingHoursEnd: json['workingHoursEnd'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyCapacity': dailyCapacity,
      'currentOrders': currentOrders,
      'isOnline': isOnline,
      'workingHoursStart': workingHoursStart,
      'workingHoursEnd': workingHoursEnd,
    };
  }
}
