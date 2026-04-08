import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/domain/customer_reels_pickup_contract.dart';

/// F.21 missing customer coordinates — reels feed must not run without lat/lng.
void main() {
  test('returns true when latitude or longitude is null', () {
    expect(customerReelsRequirePickupCoordinates(null, 46.0), isTrue);
    expect(customerReelsRequirePickupCoordinates(24.0, null), isTrue);
    expect(customerReelsRequirePickupCoordinates(null, null), isTrue);
  });

  test('returns false when both coordinates are set', () {
    expect(customerReelsRequirePickupCoordinates(24.7, 46.6), isFalse);
  });
}
