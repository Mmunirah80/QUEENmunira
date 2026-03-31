import '../../domain/entities/dish_entity.dart';
import '../../domain/repositories/menu_repository.dart';
import '../datasources/menu_mock_datasource.dart';
import '../datasources/menu_remote_datasource.dart';
import '../models/dish_model.dart';

class MenuRepositoryImpl implements MenuRepository {
  final MenuRemoteDataSource remoteDataSource;

  MenuRepositoryImpl({
    MenuRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? MenuMockDataSource();

  @override
  Future<List<DishEntity>> getDishes() async {
    try {
      final dishes = await remoteDataSource.getDishes();
      return dishes;
    } catch (e) {
      throw Exception('Failed to get dishes: ${e.toString()}');
    }
  }

  @override
  Future<DishEntity> getDishById(String id) async {
    try {
      final dish = await remoteDataSource.getDishById(id);
      return dish;
    } catch (e) {
      throw Exception('Failed to get dish: ${e.toString()}');
    }
  }

  @override
  Future<DishEntity> createDish(DishEntity dish) async {
    try {
      final dishModel = DishModel(
        id: dish.id,
        name: dish.name,
        description: dish.description,
        price: dish.price,
        imageUrl: dish.imageUrl,
        categories: dish.categories,
        isAvailable: dish.isAvailable,
        preparationTime: dish.preparationTime,
        createdAt: dish.createdAt,
      );
      final createdDish = await remoteDataSource.createDish(dishModel);
      return createdDish;
    } catch (e) {
      throw Exception('Failed to create dish: ${e.toString()}');
    }
  }

  @override
  Future<DishEntity> updateDish(DishEntity dish) async {
    try {
      final dishModel = DishModel(
        id: dish.id,
        name: dish.name,
        description: dish.description,
        price: dish.price,
        imageUrl: dish.imageUrl,
        categories: dish.categories,
        isAvailable: dish.isAvailable,
        preparationTime: dish.preparationTime,
        createdAt: dish.createdAt,
        updatedAt: dish.updatedAt,
      );
      final updatedDish = await remoteDataSource.updateDish(dishModel);
      return updatedDish;
    } catch (e) {
      throw Exception('Failed to update dish: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteDish(String id) async {
    try {
      await remoteDataSource.deleteDish(id);
    } catch (e) {
      throw Exception('Failed to delete dish: ${e.toString()}');
    }
  }

  @override
  Future<void> toggleDishAvailability(String id) async {
    try {
      await remoteDataSource.toggleDishAvailability(id);
    } catch (e) {
      throw Exception('Failed to toggle dish availability: ${e.toString()}');
    }
  }
}
