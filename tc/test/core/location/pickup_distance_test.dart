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

    test('formatPickupDistanceKm does not cap long distances (same-city browse)', () {
      expect(formatPickupDistanceKm(25), '25.0 km');
    });

    test('formatPickupDistanceKm mid range', () {
      expect(formatPickupDistanceKm(5.2), '5.2 km');
    });

    test('formatDistanceKmAway appends away', () {
      expect(formatDistanceKmAway(0.5), '0.5 km away');
      expect(formatDistanceKmAway(12.3), '12.3 km away');
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
      expect(sorted.first.distanceKm!, lessThanOrEqualTo(kFallbackBrowseRadiusWhenCityUnknownKm));
    });

    test('buildPickupSortedChefs orders nearest coordinate kitchens first', () {
      const customerLat = 24.7136;
      const customerLng = 46.6753;
      final chefs = [
        ChefDocModel(
          chefId: 'far',
          isOnline: true,
          kitchenName: 'Far',
          kitchenLatitude: 24.800,
          kitchenLongitude: 46.800,
        ),
        ChefDocModel(
          chefId: 'near',
          isOnline: true,
          kitchenName: 'Near',
          kitchenLatitude: 24.720,
          kitchenLongitude: 46.680,
        ),
      ];
      final sorted = buildPickupSortedChefs(chefs, customerLat, customerLng);
      expect(sorted.length, 2);
      expect(sorted.first.chef.chefId, 'near');
      expect(sorted.first.distanceKm!, lessThan(sorted.last.distanceKm!));
    });

    test('chefVisibleForCustomerHome matches buildHomeSortedChefs non-empty', () {
      const customerLat = 24.7136;
      const customerLng = 46.6753;
      const chefLat = 24.740;
      const chefLng = 46.720;
      final chef = ChefDocModel(
        chefId: 'c1',
        isOnline: true,
        kitchenName: 'Test Kitchen',
        kitchenLatitude: chefLat,
        kitchenLongitude: chefLng,
      );
      final list = buildHomeSortedChefs([chef], customerLat, customerLng, 'Riyadh');
      expect(list.isNotEmpty, chefVisibleForCustomerHome(chef, customerLat, customerLng, 'Riyadh'));
    });

    test('kitchenCityTextIndicatesRiyadh matches substring rules', () {
      expect(kitchenCityTextIndicatesRiyadh('الرياض'), true);
      expect(kitchenCityTextIndicatesRiyadh('North Riyadh'), true);
      expect(kitchenCityTextIndicatesRiyadh('RIYADH'), true);
      expect(kitchenCityTextIndicatesRiyadh('جدة'), false);
      expect(kitchenCityTextIndicatesRiyadh('رياض'), false);
      expect(kitchenCityTextIndicatesRiyadh(null), false);
    });

    test('chefReelGeographyMatches matches chefVisibleForCustomerHome when storefront accepts orders', () {
      const riyadhLat = 24.7136;
      const riyadhLng = 46.6753;
      const jeddahLat = 21.5;
      const jeddahLng = 39.2;
      final chef = ChefDocModel(
        chefId: 'c1',
        isOnline: true,
        kitchenName: 'Test',
        kitchenCity: 'Jeddah',
        kitchenLatitude: jeddahLat,
        kitchenLongitude: jeddahLng,
      );
      // Riyadh-area pin: Home may normalize locality to Riyadh; Reels use the raw locality string — compare only when both use the same geographic intent.
      for (final locality in <String?>[null, 'Riyadh']) {
        expect(
          chefReelGeographyMatches(chef, riyadhLat, riyadhLng, locality),
          chefVisibleForCustomerHome(chef, riyadhLat, riyadhLng, locality),
        );
      }
      expect(
        chefReelGeographyMatches(chef, jeddahLat, jeddahLng, 'Jeddah'),
        chefVisibleForCustomerHome(chef, jeddahLat, jeddahLng, 'Jeddah'),
      );
    });

    test('same-city browse includes kitchens beyond 20 km (sorted by distance)', () {
      const customerLat = 24.7136;
      const customerLng = 46.6753;
      // ~35 km straight-line north-east inside Riyadh admin area (rough)
      const farLat = 24.95;
      const farLng = 46.95;
      final farKm = haversineKm(customerLat, customerLng, farLat, farLng);
      expect(farKm, greaterThan(20.0));
      final chefs = [
        ChefDocModel(
          chefId: 'farChef',
          isOnline: true,
          kitchenName: 'Far Riyadh Kitchen',
          kitchenCity: 'الرياض',
          kitchenLatitude: farLat,
          kitchenLongitude: farLng,
        ),
      ];
      final sorted = buildHomeSortedChefs(chefs, customerLat, customerLng, 'Riyadh');
      expect(sorted, isNotEmpty);
      expect(sorted.first.chef.chefId, 'farChef');
      expect(sorted.first.distanceKm, closeTo(farKm, 0.5));
    });

    test('chefReelGeographyMatches can include offline chef in same city when Home excludes them', () {
      const customerLat = 24.7136;
      const customerLng = 46.6753;
      final chef = ChefDocModel(
        chefId: 'c1',
        isOnline: false,
        approvalStatus: 'approved',
        kitchenName: 'Test',
        kitchenCity: 'Riyadh',
        kitchenLatitude: 24.74,
        kitchenLongitude: 46.72,
      );
      expect(chefVisibleForCustomerHome(chef, customerLat, customerLng, 'Riyadh'), false);
      expect(chefReelGeographyMatches(chef, customerLat, customerLng, 'Riyadh'), true);
    });
  });
}
