/// Parsed payload from [get_admin_analytics_bundle] RPC (Supabase).
class AdminAnalyticsBundle {
  const AdminAnalyticsBundle({
    required this.ordersByDay,
    required this.revenueByDay,
    required this.ordersByMonth,
    required this.topRequestedCooks,
    required this.topSellingDishes,
    required this.peakOrderHours,
    required this.userGrowthByDay,
    required this.applicationStatusPie,
    required this.mostActiveCustomers,
    required this.highestRatedCooks,
  });

  final List<TimeSeriesPoint> ordersByDay;
  final List<RevenuePoint> revenueByDay;
  final List<NamedCount> ordersByMonth;
  final List<CookRank> topRequestedCooks;
  final List<DishRank> topSellingDishes;
  final List<HourCount> peakOrderHours;
  final List<TimeSeriesPoint> userGrowthByDay;
  final Map<String, int> applicationStatusPie;
  final List<CustomerRank> mostActiveCustomers;
  final List<CookRank> highestRatedCooks;

  factory AdminAnalyticsBundle.empty() => const AdminAnalyticsBundle(
        ordersByDay: [],
        revenueByDay: [],
        ordersByMonth: [],
        topRequestedCooks: [],
        topSellingDishes: [],
        peakOrderHours: [],
        userGrowthByDay: [],
        applicationStatusPie: {},
        mostActiveCustomers: [],
        highestRatedCooks: [],
      );

  factory AdminAnalyticsBundle.fromMap(Map<String, dynamic> map) {
    return AdminAnalyticsBundle(
      ordersByDay: _series(map['orders_by_day'], (m) => TimeSeriesPoint(
            date: (m['date'] ?? '').toString(),
            value: _i(m['count']),
          )),
      revenueByDay: _series(map['revenue_by_day'], (m) => RevenuePoint(
            date: (m['date'] ?? '').toString(),
            amount: _d(m['amount']),
          )),
      ordersByMonth: _series(map['orders_by_month'], (m) => NamedCount(
            name: (m['month'] ?? '').toString(),
            count: _i(m['count']),
          )),
      topRequestedCooks: _series(map['top_requested_cooks'], (m) => CookRank(
            cookId: (m['chef_id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            orderCount: _i(m['order_count']),
          )),
      topSellingDishes: _series(map['top_selling_dishes'], (m) => DishRank(
            dishName: (m['dish_name'] ?? '').toString(),
            ordersCount: _i(m['orders_count']),
            quantitySold: _i(m['quantity_sold']),
          )),
      peakOrderHours: _series(map['peak_order_hours'], (m) => HourCount(
            hour: _i(m['hour']),
            count: _i(m['count']),
          )),
      userGrowthByDay: _series(map['user_growth_by_day'], (m) => TimeSeriesPoint(
            date: (m['date'] ?? '').toString(),
            value: _i(m['new_users']),
          )),
      applicationStatusPie: _stringIntMap(map['application_status_pie']),
      mostActiveCustomers: _series(map['most_active_customers'], (m) => CustomerRank(
            customerId: (m['customer_id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            orderCount: _i(m['order_count']),
          )),
      highestRatedCooks: _series(map['highest_rated_cooks'], (m) => CookRank(
            cookId: (m['chef_id'] ?? m['cook_id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            orderCount: _i(m['order_count']),
            rating: (m['rating'] as num?)?.toDouble(),
          )),
    );
  }

  static List<T> _series<T>(dynamic raw, T Function(Map<String, dynamic> m) f) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return f(e);
          if (e is Map) return f(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<T>()
        .toList();
  }

  static Map<String, int> _stringIntMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      out[k.toString()] = _i(v);
    });
    return out;
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _d(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

class TimeSeriesPoint {
  const TimeSeriesPoint({required this.date, required this.value});
  final String date;
  final int value;
}

class RevenuePoint {
  const RevenuePoint({required this.date, required this.amount});
  final String date;
  final double amount;
}

class NamedCount {
  const NamedCount({required this.name, required this.count});
  final String name;
  final int count;
}

class CookRank {
  const CookRank({
    required this.cookId,
    required this.name,
    required this.orderCount,
    this.rating,
  });
  final String cookId;
  final String name;
  final int orderCount;
  final double? rating;
}

class DishRank {
  const DishRank({
    required this.dishName,
    required this.ordersCount,
    required this.quantitySold,
  });
  final String dishName;
  final int ordersCount;
  final int quantitySold;
}

class HourCount {
  const HourCount({required this.hour, required this.count});
  final int hour;
  final int count;
}

class CustomerRank {
  const CustomerRank({
    required this.customerId,
    required this.name,
    required this.orderCount,
  });
  final String customerId;
  final String name;
  final int orderCount;
}

/// [get_admin_alerts_summary] RPC.
class AdminAlertsSummary {
  const AdminAlertsSummary({
    this.expiredDocuments = 0,
    this.pendingApplications = 0,
    this.frozenAccounts = 0,
    this.reportedReels = 0,
    this.chatsNeedingReview = 0,
    this.ordersStuck = 0,
  });

  final int expiredDocuments;
  final int pendingApplications;
  final int frozenAccounts;
  final int reportedReels;
  final int chatsNeedingReview;
  final int ordersStuck;

  factory AdminAlertsSummary.fromMap(Map<String, dynamic> map) {
    int ti(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AdminAlertsSummary(
      expiredDocuments: ti(map['expired_documents']),
      pendingApplications: ti(map['pending_applications']),
      frozenAccounts: ti(map['frozen_accounts']),
      reportedReels: ti(map['reported_reels']),
      chatsNeedingReview: ti(map['chats_needing_review']),
      ordersStuck: ti(map['orders_stuck']),
    );
  }

  int get totalAttention =>
      expiredDocuments +
      pendingApplications +
      frozenAccounts +
      reportedReels +
      chatsNeedingReview +
      ordersStuck;
}
