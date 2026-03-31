class AdminDashboardStats {
  final int ordersToday;
  final double revenueToday;
  final int activeChefs;
  final int openComplaints;

  const AdminDashboardStats({
    required this.ordersToday,
    required this.revenueToday,
    required this.activeChefs,
    required this.openComplaints,
  });

  factory AdminDashboardStats.fromMap(Map<String, dynamic> map) {
    return AdminDashboardStats(
      ordersToday: _toInt(map['orders_today']),
      revenueToday: _toDouble(map['revenue_today']),
      activeChefs: _toInt(map['active_chefs']),
      openComplaints: _toInt(map['open_complaints']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

