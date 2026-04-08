import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_home_screen.dart';

/// A.1: With no pickup in session, Home shows required location prompt (no discovery body).
void main() {
  testWidgets('shows Choose your location gate when pickup origin is null', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final container = ProviderContainer(
      overrides: [
        customerPickupOriginProvider.overrideWith((ref) => null),
        customerNotificationsStreamProvider.overrideWith((ref) => Stream.value(const <Map<String, dynamic>>[])),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NahamCustomerHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your location'), findsOneWidget);
    expect(find.text('Set pickup point'), findsOneWidget);
    expect(find.text('Popular dishes'), findsNothing);
    expect(find.text('Kitchens near you'), findsNothing);
  });
}
