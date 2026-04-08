import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

/// F.21–F.24 geography edge cases (pure functions; no Supabase).
void main() {
  group('normalizeSaudiCityKey', () {
    test('F.23 variants containing riyadh normalize to riyadh', () {
      expect(normalizeSaudiCityKey('Riyadh'), 'riyadh');
      expect(normalizeSaudiCityKey('North Riyadh'), 'riyadh');
      expect(normalizeSaudiCityKey('Al Riyadh District'), 'riyadh');
    });

    test('F.23 jeddah vs jiddah normalize to jeddah', () {
      expect(normalizeSaudiCityKey('Jeddah'), 'jeddah');
      expect(normalizeSaudiCityKey('Jiddah'), 'jeddah');
    });
  });

  group('wrong city / radius', () {
    const customerLat = 24.7136;
    const customerLng = 46.6753;

    test('F.24 customer Riyadh pin + Jeddah kitchen (no matching city) → empty home scope', () {
      final chef = ChefDocModel(
        chefId: 'j1',
        isOnline: true,
        kitchenName: 'Jeddah Kitchen',
        kitchenCity: 'Jeddah',
        kitchenLatitude: 21.5,
        kitchenLongitude: 39.2,
      );
      final list = buildHomeSortedChefs([chef], customerLat, customerLng, 'Riyadh');
      expect(list, isEmpty);
    });

    test('F.22 chef without map pin does not appear in reel visibility (chefReelVisibleToCustomer)', () {
      final chef = ChefDocModel(
        chefId: 'nopin',
        approvalStatus: 'approved',
        kitchenName: 'X',
        kitchenCity: 'Riyadh',
      );
      expect(
        chefReelVisibleToCustomer(chef, customerLat, customerLng, 'Riyadh'),
        isFalse,
      );
    });
  });

  group('chef ordering distance', () {
    const customerLat = 24.7136;
    const customerLng = 46.6753;

    test('buildHomeSortedChefs orders nearest first (two Riyadh kitchens)', () {
      final near = ChefDocModel(
        chefId: 'near',
        isOnline: true,
        kitchenName: 'Near',
        kitchenCity: 'Riyadh',
        kitchenLatitude: 24.720,
        kitchenLongitude: 46.680,
      );
      final far = ChefDocModel(
        chefId: 'far',
        isOnline: true,
        kitchenName: 'Far',
        kitchenCity: 'Riyadh',
        kitchenLatitude: 24.780,
        kitchenLongitude: 46.750,
      );
      final sorted = buildHomeSortedChefs([far, near], customerLat, customerLng, 'Riyadh');
      expect(sorted.first.chef.chefId, 'near');
      expect(sorted.last.chef.chefId, 'far');
      expect(sorted.first.distanceKm, lessThan(sorted.last.distanceKm!));
    });
  });
}
