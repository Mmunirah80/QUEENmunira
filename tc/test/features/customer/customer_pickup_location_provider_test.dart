import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';

/// A.1–A.2: Session pickup starts unset; tests do not hit SharedPreferences restore (removed from shell).
void main() {
  test('customerPickupOriginProvider defaults to null (no implicit session location)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(customerPickupOriginProvider), isNull);
  });

  test('after setting Riyadh-like origin, provider exposes session coordinates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const origin = CustomerPickupOrigin(
      latitude: 24.7136,
      longitude: 46.6753,
      label: 'Riyadh',
      localityCity: 'Riyadh',
    );
    container.read(customerPickupOriginProvider.notifier).state = origin;
    expect(container.read(customerPickupOriginProvider)?.localityCity, 'Riyadh');
  });

  test('A.4 switching session location to Jeddah updates provider state (refresh driver)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(customerPickupOriginProvider.notifier).state = const CustomerPickupOrigin(
      latitude: 24.7136,
      longitude: 46.6753,
      label: 'Riyadh',
      localityCity: 'Riyadh',
    );
    container.read(customerPickupOriginProvider.notifier).state = const CustomerPickupOrigin(
      latitude: 21.5,
      longitude: 39.2,
      label: 'Jeddah',
      localityCity: 'Jeddah',
    );
    final o = container.read(customerPickupOriginProvider);
    expect(o?.localityCity, 'Jeddah');
    expect(o?.latitude, closeTo(21.5, 0.001));
  });
}
