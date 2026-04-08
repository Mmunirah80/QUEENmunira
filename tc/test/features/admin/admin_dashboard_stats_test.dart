import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/data/models/admin_dashboard_stats.dart';

void main() {
  group('AdminDashboardStats.fromMap', () {
    test('maps get_admin_dashboard_stats RPC fields', () {
      final s = AdminDashboardStats.fromMap({
        'orders_today': 12,
        'revenue_today': '340.5',
        'active_chefs': 4,
        'open_complaints': 1,
        'total_users': 100,
        'total_cooks': 20,
        'total_customers': 70,
        'total_admins': 2,
        'pending_applications': 3,
        'active_orders': 8,
        'completed_orders': 500,
        'frozen_accounts': 1,
        'open_chats': 2,
        'reported_content': 6,
        'documents_approved_total': 40,
        'documents_rejected_total': 5,
        'trend_orders_vs_yesterday_pct': '12.3',
        'trend_users_vs_week_ago_pct': null,
      });

      expect(s.ordersToday, 12);
      expect(s.revenueToday, 340.5);
      expect(s.activeChefs, 4);
      expect(s.openComplaints, 1);
      expect(s.totalUsers, 100);
      expect(s.completedOrders, 500);
      expect(s.documentsRejectedTotal, 5);
      expect(s.trendOrdersVsYesterdayPct, 12.3);
      expect(s.trendUsersVsWeekAgoPct, isNull);
    });
  });
}
