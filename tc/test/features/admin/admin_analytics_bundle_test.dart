import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/data/models/admin_analytics_bundle.dart';

void main() {
  group('AdminAnalyticsBundle.fromMap', () {
    test('parses nested lists and maps from RPC-shaped payload', () {
      final bundle = AdminAnalyticsBundle.fromMap({
        'orders_by_day': [
          {'date': '2026-04-01', 'count': 3},
        ],
        'revenue_by_day': [
          {'date': '2026-04-01', 'amount': 12.5},
        ],
        'orders_by_month': [
          {'month': '2026-03', 'count': 10},
        ],
        'top_requested_cooks': [
          {'chef_id': 'c1', 'name': 'Kitchen', 'order_count': 5},
        ],
        'top_selling_dishes': [
          {'dish_name': 'Kabsa', 'orders_count': 2, 'quantity_sold': 7},
        ],
        'peak_order_hours': [
          {'hour': 19, 'count': 4},
        ],
        'user_growth_by_day': [
          {'date': '2026-04-01', 'new_users': 2},
        ],
        'application_status_pie': {'pending': 1, 'approved': '3'},
        'most_active_customers': [
          {'customer_id': 'u1', 'name': 'A', 'order_count': 9},
        ],
        'highest_rated_cooks': [
          {'cook_id': 'c2', 'name': 'B', 'order_count': 1, 'rating': 4.5},
        ],
      });

      expect(bundle.ordersByDay.length, 1);
      expect(bundle.ordersByDay.first.date, '2026-04-01');
      expect(bundle.ordersByDay.first.value, 3);
      expect(bundle.revenueByDay.first.amount, 12.5);
      expect(bundle.ordersByMonth.first.name, '2026-03');
      expect(bundle.topRequestedCooks.first.cookId, 'c1');
      expect(bundle.topSellingDishes.first.quantitySold, 7);
      expect(bundle.peakOrderHours.first.hour, 19);
      expect(bundle.userGrowthByDay.first.value, 2);
      expect(bundle.applicationStatusPie, {'pending': 1, 'approved': 3});
      expect(bundle.mostActiveCustomers.first.customerId, 'u1');
      expect(bundle.highestRatedCooks.first.cookId, 'c2');
      expect(bundle.highestRatedCooks.first.rating, 4.5);
    });

    test('tolerates missing keys and non-map list entries', () {
      final bundle = AdminAnalyticsBundle.fromMap({
        'orders_by_day': [1, 'x'],
        'application_status_pie': 'bad',
      });
      expect(bundle.ordersByDay, isEmpty);
      expect(bundle.applicationStatusPie, isEmpty);
    });
  });

  group('AdminAlertsSummary.fromMap', () {
    test('coerces string numerics and totals', () {
      const m = {
        'expired_documents': '2',
        'pending_applications': 1,
        'frozen_accounts': 0,
        'reported_reels': 3,
        'chats_needing_review': 4,
        'orders_stuck': 5,
      };
      final s = AdminAlertsSummary.fromMap(Map<String, dynamic>.from(m));
      expect(s.totalAttention, 2 + 1 + 0 + 3 + 4 + 5);
    });
  });
}
