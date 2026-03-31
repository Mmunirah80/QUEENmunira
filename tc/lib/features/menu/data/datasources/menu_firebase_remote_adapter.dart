import 'menu_firebase_datasource.dart';
import '../models/dish_model.dart';
import 'menu_remote_datasource.dart';

/// Adapts [MenuFirebaseDataSource] (chef-scoped) to [MenuRemoteDataSource] for use by [MenuRepositoryImpl].
class MenuFirebaseRemoteAdapter implements MenuRemoteDataSource {
  final String chefId;
  final MenuFirebaseDataSource firebase;

  MenuFirebaseRemoteAdapter({required this.chefId, required this.firebase});

  @override
  Future<List<DishModel>> getDishes() async {
    if (chefId.isEmpty) return [];
    return firebase.getChefDishes(chefId);
  }

  @override
  Future<DishModel> getDishById(String id) async {
    final dish = await firebase.getDishById(id);
    if (dish == null) throw Exception('Dish not found: $id');
    return dish;
  }

  @override
  Future<DishModel> createDish(DishModel dish) async {
    if (chefId.isEmpty) throw Exception('Chef not logged in');
    return firebase.addDish(
      chefId: chefId,
      name: dish.name,
      description: dish.description,
      price: dish.price,
      preparationTime: dish.preparationTime,
      categories: dish.categories.isEmpty ? ['Other'] : dish.categories,
    );
  }

  @override
  Future<DishModel> updateDish(DishModel dish) async {
    return firebase.updateDish(
      dishId: dish.id,
      name: dish.name,
      description: dish.description,
      price: dish.price,
      preparationTime: dish.preparationTime,
      categories: dish.categories.isEmpty ? ['Other'] : dish.categories,
      isAvailable: dish.isAvailable,
      imageUrl: dish.imageUrl,
    );
  }

  @override
  Future<void> deleteDish(String id) async {
    final d = await firebase.getDishById(id);
    await firebase.deleteDish(id, imageUrl: d?.imageUrl);
  }

  @override
  Future<void> toggleDishAvailability(String id) async {
    final d = await firebase.getDishById(id);
    if (d == null) return;
    await firebase.updateAvailability(id, isAvailable: !d.isAvailable);
  }
}
