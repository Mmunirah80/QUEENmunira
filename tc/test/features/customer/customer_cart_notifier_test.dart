import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/data/models/cart_item_model.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/menu/domain/entities/dish_entity.dart';

DishEntity _dish({required String id, double price = 12.0}) {
  return DishEntity(
    id: id,
    name: 'Dish $id',
    description: '',
    price: price,
    createdAt: DateTime(2026, 1, 1),
    chefId: 'chef1',
  );
}

void main() {
  group('CartNotifier', () {
    test('add merges quantity for same dish+chef', () {
      final n = CartNotifier();
      final d = _dish(id: 'd1');
      n.add(d, 'chef1', 'Kitchen');
      n.add(d, 'chef1', 'Kitchen');
      expect(n.state.length, 1);
      expect(n.state.first.quantity, 2);
      expect(n.state.first.lineTotal, 24.0);
    });

    test('add keeps separate lines per chef', () {
      final n = CartNotifier();
      n.add(_dish(id: 'd1'), 'chef1', 'A');
      n.add(_dish(id: 'd1'), 'chef2', 'B');
      expect(n.state.length, 2);
    });

    test('updateQuantity to zero removes line', () {
      final n = CartNotifier();
      n.add(_dish(id: 'd1'), 'chef1', 'K');
      n.updateQuantity('d1', 'chef1', 0);
      expect(n.state, isEmpty);
    });

    test('clear empties cart', () {
      final n = CartNotifier();
      n.add(_dish(id: 'd1'), 'chef1', 'K');
      n.clear();
      expect(n.state, isEmpty);
    });
  });

  group('cartQuantityForDishChef', () {
    test('sums quantity for matching dish and chef only', () {
      final cart = [
        CartItemModel(
          dishId: 'a',
          dishName: 'A',
          chefId: 'c1',
          chefName: 'K',
          price: 10,
          quantity: 2,
        ),
        CartItemModel(
          dishId: 'a',
          dishName: 'A',
          chefId: 'c2',
          chefName: 'K2',
          price: 10,
          quantity: 1,
        ),
      ];
      expect(cartQuantityForDishChef(cart, 'a', 'c1'), 2);
      expect(cartQuantityForDishChef(cart, 'a', 'c2'), 1);
      expect(cartQuantityForDishChef(cart, 'b', 'c1'), 0);
    });
  });
}
