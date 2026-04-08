import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/customer/domain/customer_discovery_sorting.dart';
import 'package:naham_cook_app/features/menu/domain/entities/dish_entity.dart';

void main() {
  group('sortDishesByChefDistanceOrder', () {
    final t0 = DateTime.utc(2025, 1, 1);

    DishEntity dish(String id, String name, String chefId) => DishEntity(
          id: id,
          name: name,
          description: '',
          price: 1,
          createdAt: t0,
          chefId: chefId,
        );

    test('orders dishes by sorted chef list (nearest first), then by dish name', () {
      final sortedChefs = [
        ChefWithPickupDistance(
          ChefDocModel(chefId: 'near', kitchenName: 'A', kitchenLatitude: 1, kitchenLongitude: 1),
          1.0,
        ),
        ChefWithPickupDistance(
          ChefDocModel(chefId: 'far', kitchenName: 'B', kitchenLatitude: 2, kitchenLongitude: 2),
          10.0,
        ),
      ];
      final dishes = [
        dish('d2', 'Z', 'far'),
        dish('d1', 'A', 'near'),
        dish('d3', 'B', 'near'),
      ];
      final out = sortDishesByChefDistanceOrder(dishes, sortedChefs);
      expect(out.map((e) => e.id).toList(), ['d1', 'd3', 'd2']);
    });

    test('equal chef distance bucket: deterministic tie-break by dish name', () {
      final sortedChefs = [
        ChefWithPickupDistance(
          ChefDocModel(chefId: 'c1', kitchenName: 'A', kitchenLatitude: 1, kitchenLongitude: 1),
          2.0,
        ),
      ];
      final dishes = [
        dish('x', 'Banana', 'c1'),
        dish('y', 'Apple', 'c1'),
      ];
      final out = sortDishesByChefDistanceOrder(dishes, sortedChefs);
      expect(out.map((e) => e.name).toList(), ['Apple', 'Banana']);
    });

    test('unknown chef id sorts after known (9999 bucket)', () {
      final sortedChefs = [
        ChefWithPickupDistance(
          ChefDocModel(chefId: 'known', kitchenName: 'K', kitchenLatitude: 1, kitchenLongitude: 1),
          1.0,
        ),
      ];
      final dishes = [
        dish('a', 'A', 'orphan'),
        dish('b', 'B', 'known'),
      ];
      final out = sortDishesByChefDistanceOrder(dishes, sortedChefs);
      expect(out.first.chefId, 'known');
      expect(out.last.chefId, 'orphan');
    });
  });
}
