class AdminDashboardStats {
  final int ordersToday;
  final double revenueToday;
  /// Online cooks (legacy RPC field).
  final int activeChefs;
  final int openComplaints;

  final int totalUsers;
  final int totalCooks;
  final int totalCustomers;
  final int totalAdmins;
  final int pendingApplications;
  final int activeOrders;
  final int completedOrders;
  final int frozenAccounts;
  final int openChats;
  final int reportedContent;
  final int documentsApprovedTotal;
  final int documentsRejectedTotal;
  final double? trendOrdersVsYesterdayPct;
  final double? trendUsersVsWeekAgoPct;

  const AdminDashboardStats({
    required this.ordersToday,
    required this.revenueToday,
    required this.activeChefs,
    required this.openComplaints,
    this.totalUsers = 0,
    this.totalCooks = 0,
    this.totalCustomers = 0,
    this.totalAdmins = 0,
    this.pendingApplications = 0,
    this.activeOrders = 0,
    this.completedOrders = 0,
    this.frozenAccounts = 0,
    this.openChats = 0,
    this.reportedContent = 0,
    this.documentsApprovedTotal = 0,
    this.documentsRejectedTotal = 0,
    this.trendOrdersVsYesterdayPct,
    this.trendUsersVsWeekAgoPct,
  });

  factory AdminDashboardStats.fromMap(Map<String, dynamic> map) {
    return AdminDashboardStats(
      ordersToday: _toInt(map['orders_today']),
      revenueToday: _toDouble(map['revenue_today']),
      activeChefs: _toInt(map['active_chefs']),
      openComplaints: _toInt(map['open_complaints']),
      totalUsers: _toInt(map['total_users']),
      totalCooks: _toInt(map['total_cooks']),
      totalCustomers: _toInt(map['total_customers']),
      totalAdmins: _toInt(map['total_admins']),
      pendingApplications: _toInt(map['pending_applications']),
      activeOrders: _toInt(map['active_orders']),
      completedOrders: _toInt(map['completed_orders']),
      frozenAccounts: _toInt(map['frozen_accounts']),
      openChats: _toInt(map['open_chats']),
      reportedContent: _toInt(map['reported_content']),
      documentsApprovedTotal: _toInt(map['documents_approved_total']),
      documentsRejectedTotal: _toInt(map['documents_rejected_total']),
      trendOrdersVsYesterdayPct: _toDoubleNullable(map['trend_orders_vs_yesterday_pct']),
      trendUsersVsWeekAgoPct: _toDoubleNullable(map['trend_users_vs_week_ago_pct']),
    );
  }

  static double? _toDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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
