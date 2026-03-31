import '../../domain/entities/dish_entity.dart';
import '../models/dish_model.dart';

abstract class MenuRemoteDataSource {
  Future<List<DishModel>> getDishes();
  Future<DishModel> getDishById(String id);
  Future<DishModel> createDish(DishModel dish);
  Future<DishModel> updateDish(DishModel dish);
  Future<void> deleteDish(String id);
  Future<void> toggleDishAvailability(String id);
}
