import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_home_screen.dart';
import 'package:naham_cook_app/features/menu/domain/entities/dish_entity.dart';

/// With no saved pickup, Home uses Riyadh demo browse and still renders the discovery scaffold
/// (chefs from [chefsForCustomerStreamProvider], dishes from [availableDishesStreamProvider] — independent).
void main() {
  testWidgets('with null pickup, shows demo browse line and kitchens section (not blocked on dishes)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final container = ProviderContainer(
      overrides: [
        customerPickupOriginProvider.overrideWith((ref) => null),
        customerNotificationsStreamProvider.overrideWith((ref) => Stream.value(const <Map<String, dynamic>>[])),
        availableDishesStreamProvider.overrideWith((ref) => Stream.value(const <DishEntity>[])),
        chefsForCustomerStreamProvider.overrideWith(
          (ref) => Stream.value(const <ChefDocModel>[]),
        ),
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

    expect(find.textContaining('Demo: showing Riyadh kitchens'), findsOneWidget);
    expect(find.text('Pickup point not set'), findsOneWidget);
    expect(find.text('No kitchens for this pickup'), findsOneWidget);
  });
}
