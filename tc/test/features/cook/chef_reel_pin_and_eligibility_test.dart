import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

/// Chef reels: own scope is tested elsewhere; here — geography + account + pin rules.
void main() {
  ChefDocModel approvedChef({
    double? lat,
    double? lng,
    String? city,
    bool frozen = false,
    bool suspended = false,
  }) {
    return ChefDocModel(
      kitchenLatitude: lat,
      kitchenLongitude: lng,
      kitchenCity: city,
      approvalStatus: 'approved',
      suspended: suspended,
      freezeUntil: frozen ? DateTime.now().add(const Duration(days: 1)) : null,
    );
  }

  group('chefReelVisibleToCustomer', () {
    test('no kitchen pin → never visible on customer reels', () {
      final c = approvedChef(lat: null, lng: null, city: 'Riyadh');
      expect(c.hasKitchenMapPin, isFalse);
      expect(
        chefReelVisibleToCustomer(c, 24.7, 46.7, 'Riyadh'),
        isFalse,
      );
    });

    test('suspended chef → not visible', () {
      final c = approvedChef(lat: 24.7, lng: 46.7, city: 'Riyadh', suspended: true);
      expect(chefReelVisibleToCustomer(c, 24.7, 46.7, 'Riyadh'), isFalse);
    });

    test('active freeze → not eligible for public reel', () {
      final c = approvedChef(lat: 24.7, lng: 46.7, city: 'Riyadh', frozen: true);
      expect(chefReelAccountEligibleForPublicFeed(c), isFalse);
    });
  });
}
