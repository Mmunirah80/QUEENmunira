import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

/// C.7–C.9 and location-change behaviour using reels/home shared geography helpers
/// ([buildHomeSortedChefsForReels] has no storefront filter — deterministic without hours).
void main() {
  const customerLat = 24.7136;
  const customerLng = 46.6753;

  ChefDocModel riyadhChef({
    required String id,
    required double lat,
    required double lng,
    required String name,
  }) {
    return ChefDocModel(
      chefId: id,
      kitchenName: name,
      kitchenCity: 'Riyadh',
      kitchenLatitude: lat,
      kitchenLongitude: lng,
    );
  }

  test('buildHomeSortedChefsForReels sorts by distance nearest first within city scope', () {
    final near = riyadhChef(id: 'n', lat: 24.72, lng: 46.68, name: 'Near');
    final far = riyadhChef(id: 'f', lat: 24.85, lng: 46.90, name: 'Far');
    final out = buildHomeSortedChefsForReels(
      [far, near],
      customerLat,
      customerLng,
      'Riyadh',
    );
    expect(out.length, 2);
    expect(out.first.chef.chefId, 'n');
    expect(out.last.chef.chefId, 'f');
    expect(out.first.distanceKm!.compareTo(out.last.distanceKm!), lessThan(0));
  });

  test('Jeddah pickup pin + Jeddah coords excludes Riyadh-only kitchen (city then radius)', () {
    const jeddahLat = 21.5;
    const jeddahLng = 39.2;
    final riyadhOnly = riyadhChef(id: 'r', lat: 24.72, lng: 46.68, name: 'R');
    final out = buildHomeSortedChefsForReels(
      [riyadhOnly],
      jeddahLat,
      jeddahLng,
      'Jeddah',
    );
    expect(out, isEmpty);
  });

  test('chef kitchen pin moves to another city — reel geography no longer matches Riyadh pickup', () {
    final inRiyadh = riyadhChef(id: 'mov', lat: 24.72, lng: 46.68, name: 'M');
    expect(
      chefReelGeographyMatches(inRiyadh, customerLat, customerLng, 'Riyadh'),
      isTrue,
    );

    final moved = ChefDocModel(
      chefId: 'mov',
      kitchenName: 'M',
      kitchenCity: 'Jeddah',
      kitchenLatitude: 21.5,
      kitchenLongitude: 39.2,
    );
    expect(
      chefReelGeographyMatches(moved, customerLat, customerLng, 'Riyadh'),
      isFalse,
    );
  });
}
