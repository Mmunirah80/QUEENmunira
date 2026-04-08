import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
/// Unified cancellation copy: only two customer-facing strings (see product rules).
void main() {
  group('OrderDbStatus cancellation — internal cancel_reason', () {
    test('cook_rejected → Rejected by cook', () {
      expect(
        OrderDbStatus.customerFacingLabel(
          'cancelled',
          cancelReason: OrderDbStatus.internalCookRejected,
        ),
        'Rejected by cook',
      );
      expect(
        OrderDbStatus.customerCancellationSummary(
          'cancelled',
          cancelReason: OrderDbStatus.internalCookRejected,
        ),
        'Rejected by cook',
      );
    });

    test('system_cancelled_frozen → Cancelled by system', () {
      expect(
        OrderDbStatus.customerFacingLabel(
          'cancelled',
          cancelReason: OrderDbStatus.internalSystemCancelledFrozen,
        ),
        'Cancelled by system',
      );
    });

    test('system_cancelled_blocked → Cancelled by system', () {
      expect(
        OrderDbStatus.customerFacingLabel(
          'cancelled',
          cancelReason: OrderDbStatus.internalSystemCancelledBlocked,
        ),
        'Cancelled by system',
      );
    });

    test('cancel_reason wins over legacy status when both present', () {
      expect(
        OrderDbStatus.customerFacingLabel(
          'cancelled_by_cook',
          cancelReason: OrderDbStatus.internalSystemCancelledFrozen,
        ),
        'Cancelled by system',
      );
    });
  });

  group('OrderDbStatus cancellation — legacy DB status (no cancel_reason)', () {
    test('cancelled_by_cook → Rejected by cook', () {
      expect(
        OrderDbStatus.customerFacingLabel('cancelled_by_cook'),
        'Rejected by cook',
      );
    });

    test('rejected → Rejected by cook', () {
      expect(OrderDbStatus.customerFacingLabel('rejected'), 'Rejected by cook');
    });

    test('cancelled_by_customer → Cancelled by system (legacy bucket)', () {
      expect(
        OrderDbStatus.customerFacingLabel('cancelled_by_customer'),
        'Cancelled by system',
      );
    });

    test('expired → Cancelled by system (legacy bucket)', () {
      expect(
        OrderDbStatus.customerFacingLabel('expired'),
        'Cancelled by system',
      );
    });
  });

  group('OrderDbStatus — no raw internal strings in customer labels', () {
    test('unknown cancel_reason falls through to status / fallback only', () {
      final v = OrderDbStatus.customerFacingLabel(
        'cancelled',
        cancelReason: 'some_future_internal_reason',
      );
      expect(v, isNot(contains('some_future')));
      expect(v, isNot(contains('_')));
    });
  });

  group('customerCancellationSummary — terminal fallbacks', () {
    test('uses cook mapping for cancelled_by_cook', () {
      expect(
        OrderDbStatus.customerCancellationSummary('cancelled_by_cook'),
        'Rejected by cook',
      );
    });
  });
}
