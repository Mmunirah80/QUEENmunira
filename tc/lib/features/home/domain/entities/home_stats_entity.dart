import 'package:equatable/equatable.dart';

class HomeStatsEntity extends Equatable {
  final int dailyCapacity;
  final int currentOrders;
  final bool isOnline;
  final String? workingHoursStart;
  final String? workingHoursEnd;

  const HomeStatsEntity({
    required this.dailyCapacity,
    required this.currentOrders,
    required this.isOnline,
    this.workingHoursStart,
    this.workingHoursEnd,
  });

  @override
  List<Object?> get props => [
        dailyCapacity,
        currentOrders,
        isOnline,
        workingHoursStart,
        workingHoursEnd,
      ];
}
