import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../domain/repositories/analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepositoryImpl();
});

final analyticsProvider = FutureProvider<AnalyticsEntity>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return await repository.getAnalytics();
});
