import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_model.dart';

/// Admin: all orders (no chefId filter). Collection path matches TC: 'orders'.
class OrdersFirebaseDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col => _firestore.collection('orders');

  Future<List<OrderModel>> getOrders() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs.map(_fromDoc).toList();
  }

  Stream<List<OrderModel>> watchOrders() {
    return _col.orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map(_fromDoc).toList());
  }

  /// Delayed = pending/accepted/preparing and createdAt older than [threshold].
  static const Duration delayedThreshold = Duration(minutes: 30);

  Stream<int> watchDelayedOrdersCount() {
    final cutoff = DateTime.now().subtract(delayedThreshold);
    final cutoffTs = Timestamp.fromDate(cutoff);
    return _col
        .where('createdAt', isLessThan: cutoffTs)
        .snapshots()
        .map((snap) {
      final active = ['pending', 'accepted', 'preparing'];
      return snap.docs.where((d) => active.contains(((d.data() as Map<String, dynamic>?) ?? <String, dynamic>{})['status'] as String?)).length;
    });
  }

  Stream<int> watchTodayOrdersCount() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<double> watchTodayRevenue() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snap) {
      double sum = 0;
      for (final doc in snap.docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        sum += total;
      }
      return sum;
    });
  }

  /// Last 7 days daily revenue for chart. Index 0 = oldest day.
  Future<List<double>> getLast7DaysRevenue() async {
    final now = DateTime.now();
    final list = <double>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      final snap = await _col
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .where('status', isEqualTo: 'completed')
          .get();
      double sum = 0;
      for (final doc in snap.docs) {
        sum += (((doc.data() as Map<String, dynamic>?) ?? {})['totalAmount'] as num?)?.toDouble() ?? 0;
      }
      list.add(sum);
    }
    return list;
  }

  Future<int> getTotalOrdersCount() async {
    final snap = await _col.count().get();
    return snap.count ?? 0;
  }

  Future<int> getThisMonthOrdersCount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = now.month < 12 ? DateTime(now.year, now.month + 1, 1) : DateTime(now.year + 1, 1, 1);
    final snap = await _col
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Most ordered dish names (from order items). Returns list of (dishName, count) sorted by count desc.
  Future<List<MapEntry<String, int>>> getMostOrderedDishes({int limit = 10}) async {
    final snap = await _col.get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final items = ((doc.data() as Map<String, dynamic>?) ?? {})['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final name = (item as Map<String, dynamic>)['dishName'] as String? ?? '';
        if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final list = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).toList();
  }

  /// Most active chefs (by order count). Returns list of (chefId/chefName, count).
  Future<List<MapEntry<String, int>>> getMostActiveChefs({int limit = 10}) async {
    final snap = await _col.get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final chefId = data['chefId'] as String? ?? data['chefName'] as String? ?? '—';
      final key = chefId.isEmpty ? '—' : chefId;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).toList();
  }

  /// Peak order hours (0-23). Returns map hour -> count.
  Future<Map<int, int>> getPeakOrderHours() async {
    final snap = await _col.get();
    final byHour = <int, int>{};
    for (int i = 0; i < 24; i++) byHour[i] = 0;
    for (final doc in snap.docs) {
      final createdAt = ((doc.data() as Map<String, dynamic>?) ?? {})['createdAt'];
      DateTime? dt;
      if (createdAt is Timestamp) dt = createdAt.toDate();
      if (dt != null) {
        byHour[dt.hour] = (byHour[dt.hour] ?? 0) + 1;
      }
    }
    return byHour;
  }

  OrderModel _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OrderModel.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
    });
  }
}
