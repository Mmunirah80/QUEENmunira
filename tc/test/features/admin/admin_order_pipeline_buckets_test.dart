import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/domain/admin_order_pipeline_buckets.dart';

void main() {
  test('adminOrderPipelineBucketsFromOrderRows classifies statuses into pipeline keys', () {
    final buckets = adminOrderPipelineBucketsFromOrderRows([
      {'status': 'pending'},
      {'status': 'paid_waiting_acceptance'},
      {'status': 'accepted'},
      {'status': 'preparing'},
      {'status': 'ready'},
      {'status': 'completed'},
      {'status': 'cancelled'},
      {'status': 'rejected'},
      {'status': 'weird_future_status'},
    ]);

    expect(buckets['awaiting'], 3); // pending, paid_waiting_acceptance, unknown
    expect(buckets['accepted'], 1);
    expect(buckets['preparing'], 1);
    expect(buckets['ready'], 1);
    expect(buckets['completed'], 1);
    expect(buckets['cancelled'], 2);
  });
}
