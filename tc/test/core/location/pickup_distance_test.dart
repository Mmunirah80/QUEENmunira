import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

void main() {
  group('pickup_distance', () {
    test('haversineKm same coordinates is ~0', () {
      expect(haversineKm(24.7136, 46.6753, 24.7136, 46.6753), lessThan(0.02));
    });

    test('formatPickupDistanceKm uses km only; floors at 500 m', () {
      expect(formatPickupDistanceKm(0.04), '0.5 km');
      expect(formatPickupDistanceKm(0.4), '0.5 km');
      expect(formatPickupDistanceKm(0.5), '0.5 km');
      expect(formatPickupDistanceKm(0.6), '0.6 km');
    });

    test('formatPickupDistanceKm caps at 20 km', () {
      expect(formatPickupDistanceKm(25), '20.0 km');
    });

    test('formatPickupDistanceKm mid range', () {
      expect(formatPickupDistanceKm(5.2), '5.2 km');
    });

    test('buildPickupSortedChefs includes cook with pin within radius', () {
      const customerLat = 24.7136;
      const customerLng = 46.6753;
      // ~3 km north-east in same metro (rough)
      const chefLat = 24.740;
      const chefLng = 46.720;
      final chefs = [
        ChefDocModel(
          chefId: 'c1',
          isOnline: true,
          kitchenName: 'Test Kitchen',
          kitchenLatitude: chefLat,
          kitchenLongitude: chefLng,
        ),
      ];
      final sorted = buildPickupSortedChefs(chefs, customerLat, customerLng);
      expect(sorted, isNotEmpty);
      expect(sorted.first.distanceKm, isNotNull);
      expect(sorted.first.distanceKm!, lessThanOrEqualTo(kMaxPickupRadiusKm));
    });
  });
}
