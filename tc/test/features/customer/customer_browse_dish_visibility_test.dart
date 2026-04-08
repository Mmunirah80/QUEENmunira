import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/domain/customer_browse_dish_visibility.dart';

void main() {
  group('menuItemRowVisibleInCustomerBrowse', () {
    test('available, approved, remaining>0 → visible', () {
      expect(
        menuItemRowVisibleInCustomerBrowse(
          isAvailable: true,
          moderationStatus: 'approved',
          remainingQuantity: 3,
        ),
        isTrue,
      );
    });

    test('null moderation (legacy) is treated like approved path', () {
      expect(
        menuItemRowVisibleInCustomerBrowse(
          isAvailable: true,
          moderationStatus: null,
          remainingQuantity: 1,
        ),
        isTrue,
      );
    });

    test('rejected moderation hides dish', () {
      expect(
        menuItemRowVisibleInCustomerBrowse(
          isAvailable: true,
          moderationStatus: 'rejected',
          remainingQuantity: 5,
        ),
        isFalse,
      );
    });

    test('sold out hides dish', () {
      expect(
        menuItemRowVisibleInCustomerBrowse(
          isAvailable: true,
          moderationStatus: 'approved',
          remainingQuantity: 0,
        ),
        isFalse,
      );
    });

    test('unavailable flag hides dish', () {
      expect(
        menuItemRowVisibleInCustomerBrowse(
          isAvailable: false,
          moderationStatus: 'approved',
          remainingQuantity: 10,
        ),
        isFalse,
      );
    });
  });
}
