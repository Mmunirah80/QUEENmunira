import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

/// B.5–B.6: Document when Home (storefront) and Reels (geo + account) align or diverge by design.
void main() {
  const customerLat = 24.7136;
  const customerLng = 46.6753;

  test(
    'B.6 when chef is online and storefront accepts orders, reel geography matches home geography for same pin',
    () {
      final chef = ChefDocModel(
        chefId: 'c1',
        isOnline: true,
        approvalStatus: 'approved',
        kitchenName: 'K',
        kitchenCity: 'Riyadh',
        kitchenLatitude: 24.74,
        kitchenLongitude: 46.72,
      );
      expect(chefVisibleForCustomerHome(chef, customerLat, customerLng, 'Riyadh'), isTrue);
      expect(chefReelGeographyMatches(chef, customerLat, customerLng, 'Riyadh'), isTrue);
    },
  );

  test(
    'B.6 product-allowed mismatch: offline chef may match reels geography but not Home storefront',
    () {
      final chef = ChefDocModel(
        chefId: 'c2',
        isOnline: false,
        approvalStatus: 'approved',
        kitchenName: 'K',
        kitchenCity: 'Riyadh',
        kitchenLatitude: 24.74,
        kitchenLongitude: 46.72,
      );
      expect(chefVisibleForCustomerHome(chef, customerLat, customerLng, 'Riyadh'), isFalse);
      expect(chefReelGeographyMatches(chef, customerLat, customerLng, 'Riyadh'), isTrue);
    },
  );

  test(
    'B.5 reels full customer visibility also requires map pin + account (stricter than geography alone)',
    () {
      final chef = ChefDocModel(
        chefId: 'c3',
        isOnline: true,
        approvalStatus: 'approved',
        kitchenName: 'K',
        kitchenCity: 'Riyadh',
        kitchenLatitude: 24.74,
        kitchenLongitude: 46.72,
      );
      expect(chefReelVisibleToCustomer(chef, customerLat, customerLng, 'Riyadh'), isTrue);

      final noPin = ChefDocModel(
        chefId: 'c4',
        isOnline: true,
        approvalStatus: 'approved',
        kitchenName: 'K',
        kitchenCity: 'Riyadh',
      );
      expect(
        chefReelGeographyMatches(noPin, customerLat, customerLng, 'Riyadh'),
        isTrue,
      );
      expect(
        chefReelVisibleToCustomer(noPin, customerLat, customerLng, 'Riyadh'),
        isFalse,
      );
    },
  );
}
