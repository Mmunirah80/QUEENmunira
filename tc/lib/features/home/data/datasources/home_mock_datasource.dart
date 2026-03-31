import '../../../../core/constants/app_constants.dart';
import '../models/home_stats_model.dart';
import 'home_remote_datasource.dart';

class HomeMockDataSource implements HomeRemoteDataSource {
  int _dailyCapacity = AppConstants.defaultCapacity;
  bool _isOnline = false;
  String? _workingHoursStart;
  String? _workingHoursEnd;

  @override
  Future<HomeStatsModel> getHomeStats() async {
    await Future.delayed(AppConstants.mockDelay);
    return HomeStatsModel(
      dailyCapacity: _dailyCapacity,
      currentOrders: 5, // Mock current orders
      isOnline: _isOnline,
      workingHoursStart: _workingHoursStart,
      workingHoursEnd: _workingHoursEnd,
    );
  }

  @override
  Future<void> updateDailyCapacity(int capacity) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _dailyCapacity = capacity;
  }

  @override
  Future<void> toggleOnlineStatus(bool isOnline) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _isOnline = isOnline;
  }

  @override
  Future<void> updateWorkingHours(String? start, String? end) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _workingHoursStart = start;
    _workingHoursEnd = end;
  }
}
