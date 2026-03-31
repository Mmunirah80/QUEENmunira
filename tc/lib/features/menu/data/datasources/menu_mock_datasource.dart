import 'dart:math';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/dish_entity.dart';
import '../models/dish_model.dart';
import 'menu_remote_datasource.dart';

class MenuMockDataSource implements MenuRemoteDataSource {
  final List<DishModel> _dishes = [];

  MenuMockDataSource() {
    _initializeMockData();
  }

  void _initializeMockData() {
    final dishes = [
      {
        'name': 'Chicken Biryani',
        'description': 'Fragrant basmati rice cooked with tender chicken and aromatic spices',
        'price': 25.99,
        'categories': ['Main Course', 'Rice'],
        'preparationTime': 45,
      },
      {
        'name': 'Beef Kabsa',
        'description': 'Traditional Saudi rice dish with spiced beef',
        'price': 32.99,
        'categories': ['Main Course', 'Rice'],
        'preparationTime': 60,
      },
      {
        'name': 'Shawarma Plate',
        'description': 'Marinated chicken with tahini sauce, pickles, and fries',
        'price': 18.99,
        'categories': ['Main Course', 'Chicken'],
        'preparationTime': 30,
      },
      {
        'name': 'Hummus',
        'description': 'Creamy chickpea dip with tahini and olive oil',
        'price': 8.99,
        'categories': ['Appetizer', 'Vegetarian'],
        'preparationTime': 15,
      },
      {
        'name': 'Kunafa',
        'description': 'Sweet pastry with cheese and syrup',
        'price': 12.99,
        'categories': ['Dessert'],
        'preparationTime': 20,
      },
    ];

    for (int i = 0; i < dishes.length; i++) {
      _dishes.add(
        DishModel(
          id: 'dish_$i',
          name: dishes[i]['name'] as String,
          description: dishes[i]['description'] as String,
          price: dishes[i]['price'] as double,
          categories: dishes[i]['categories'] as List<String>,
          preparationTime: dishes[i]['preparationTime'] as int,
          createdAt: DateTime.now().subtract(Duration(days: i)),
          isAvailable: Random().nextBool(),
        ),
      );
    }
  }

  @override
  Future<List<DishModel>> getDishes() async {
    await Future.delayed(AppConstants.mockDelay);
    return List.from(_dishes);
  }

  @override
  Future<DishModel> getDishById(String id) async {
    await Future.delayed(AppConstants.mockDelay);
    return _dishes.firstWhere(
      (dish) => dish.id == id,
      orElse: () => throw Exception('Dish not found'),
    );
  }

  @override
  Future<DishModel> createDish(DishModel dish) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final newDish = DishModel(
      id: 'dish_${DateTime.now().millisecondsSinceEpoch}',
      name: dish.name,
      description: dish.description,
      price: dish.price,
      imageUrl: dish.imageUrl,
      categories: dish.categories,
      isAvailable: dish.isAvailable,
      preparationTime: dish.preparationTime,
      createdAt: DateTime.now(),
    );
    _dishes.add(newDish);
    return newDish;
  }

  @override
  Future<DishModel> updateDish(DishModel dish) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final index = _dishes.indexWhere((d) => d.id == dish.id);
    if (index == -1) {
      throw Exception('Dish not found');
    }
    _dishes[index] = DishModel(
      id: dish.id,
      name: dish.name,
      description: dish.description,
      price: dish.price,
      imageUrl: dish.imageUrl,
      categories: dish.categories,
      isAvailable: dish.isAvailable,
      preparationTime: dish.preparationTime,
      createdAt: dish.createdAt,
      updatedAt: DateTime.now(),
    );
    return _dishes[index];
  }

  @override
  Future<void> deleteDish(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _dishes.removeWhere((dish) => dish.id == id);
  }

  @override
  Future<void> toggleDishAvailability(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _dishes.indexWhere((dish) => dish.id == id);
    if (index != -1) {
      _dishes[index] = DishModel(
        id: _dishes[index].id,
        name: _dishes[index].name,
        description: _dishes[index].description,
        price: _dishes[index].price,
        imageUrl: _dishes[index].imageUrl,
        categories: _dishes[index].categories,
        isAvailable: !_dishes[index].isAvailable,
        preparationTime: _dishes[index].preparationTime,
        createdAt: _dishes[index].createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }
}
