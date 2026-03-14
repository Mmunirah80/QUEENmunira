import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingChefsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return const Stream.empty();
});

final pendingChefsCountProvider = StreamProvider<int>((ref) {
  return const Stream.empty();
});

final allChefsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return [];
});

final allCustomersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return [];
});

final allOrdersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return const Stream.empty();
});

final delayedOrdersCountProvider = StreamProvider<int>((ref) {
  return const Stream.empty();
});

final todayOrdersCountProvider = StreamProvider<int>((ref) {
  return const Stream.empty();
});

final todayRevenueProvider = StreamProvider<double>((ref) {
  return const Stream.empty();
});

final supportUnreadCountProvider = StreamProvider<int>((ref) {
  return const Stream.empty();
});

final adminNotificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return const Stream.empty();
});

final supportConversationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return const Stream.empty();
});

// Analytics (one-time fetch)
final totalOrdersCountProvider = FutureProvider<int>((ref) async {
  return 0;
});

final thisMonthOrdersCountProvider = FutureProvider<int>((ref) async {
  return 0;
});

final last7DaysRevenueProvider = FutureProvider<List<double>>((ref) async {
  return const [];
});

final mostOrderedDishesProvider = FutureProvider<List<MapEntry<String, int>>>((ref) async {
  return const [];
});

final mostActiveChefsProvider = FutureProvider<List<MapEntry<String, int>>>((ref) async {
  return const [];
});

final peakOrderHoursProvider = FutureProvider<Map<int, int>>((ref) async {
  return const {};
});

final supportMessagesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, conversationId) {
  return const Stream.empty();
});
