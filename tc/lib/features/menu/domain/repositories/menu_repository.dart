import '../entities/dish_entity.dart';

abstract class MenuRepository {
  Future<List<DishEntity>> getDishes();
  Future<DishEntity> getDishById(String id);
  Future<DishEntity> createDish(DishEntity dish);
  Future<DishEntity> updateDish(DishEntity dish);
  Future<void> deleteDish(String id);
  Future<void> toggleDishAvailability(String id);
}
