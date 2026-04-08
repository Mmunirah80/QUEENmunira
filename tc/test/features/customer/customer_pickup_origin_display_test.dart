import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';

void main() {
  group('CustomerPickupOrigin.headerLine', () {
    test('uses detailLabel when non-empty', () {
      const o = CustomerPickupOrigin(
        latitude: 24.7,
        longitude: 46.6,
        label: 'Short',
        detailLabel: 'Area · Riyadh · SA',
        localityCity: 'Riyadh',
      );
      expect(o.headerLine, 'Area · Riyadh · SA');
    });

    test('falls back to label then default', () {
      const o1 = CustomerPickupOrigin(
        latitude: 24.7,
        longitude: 46.6,
        label: 'Al Olaya',
        detailLabel: '',
        localityCity: 'Riyadh',
      );
      expect(o1.headerLine, 'Al Olaya');

      const o2 = CustomerPickupOrigin(
        latitude: 24.7,
        longitude: 46.6,
        label: '',
        detailLabel: '   ',
        localityCity: null,
      );
      expect(o2.headerLine, 'Pickup point');
    });
  });

  group('CustomerLocationData.displayText', () {
    test('district + city preferred', () {
      const d = CustomerLocationData(region: 'Riyadh', city: 'Riyadh', district: 'Al Olaya');
      expect(d.displayText, 'Al Olaya, Riyadh');
    });

    test('city only', () {
      const d = CustomerLocationData(region: '', city: 'Jeddah', district: '');
      expect(d.displayText, 'Jeddah');
    });
  });
}
