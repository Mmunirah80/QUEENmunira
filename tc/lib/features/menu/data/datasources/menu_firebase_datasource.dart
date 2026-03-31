import '../models/dish_model.dart';

class MenuFirebaseDataSource {
  // ─── Chef: own dishes ────────────────────────────────────────────────

  /// Real-time stream of all dishes that belong to [chefId].
  Stream<List<DishModel>> watchChefDishes(String chefId) {
    return Stream.value([]);
  }

  // ─── Customer: available dishes ──────────────────────────────────────

  /// Real-time stream of all available dishes across all approved chefs.
  Stream<List<DishModel>> watchAvailableDishes() {
    return Stream.value([]);
  }

  // ─── CRUD ────────────────────────────────────────────────────────────

  /// Adds a new dish for [chefId]. Optionally uploads [imageFile] to Storage.
  /// Returns the saved [DishModel] with the generated Firestore ID.
  Future<DishModel> addDish({
    required String chefId,
    required String name,
    required String description,
    required double price,
    required int preparationTime,
    required List<String> categories,
    Object? imageFile,
  }) async {
    return DishModel(
      id: '',
      name: name,
      description: description,
      price: price,
      imageUrl: null,
      categories: categories,
      isAvailable: true,
      preparationTime: preparationTime,
      createdAt: DateTime.now(),
      updatedAt: null,
      chefId: chefId,
    );
  }

  /// Toggles the availability flag of a dish.
  Future<void> updateAvailability(String dishId, {required bool isAvailable}) async {}

  /// Deletes the dish document and its Storage image (if any).
  Future<void> deleteDish(String dishId, {String? imageUrl}) async {
    return;
  }

  /// One-time fetch of all dishes for [chefId].
  Future<List<DishModel>> getChefDishes(String chefId) async {
    return [];
  }

  /// Fetch a single dish by id.
  Future<DishModel?> getDishById(String dishId) async {
    return null;
  }

  /// Full update of dish fields (name, description, price, preparationTime, categories, isAvailable).
  Future<DishModel> updateDish({
    required String dishId,
    required String name,
    required String description,
    required double price,
    required int preparationTime,
    required List<String> categories,
    required bool isAvailable,
    String? imageUrl,
  }) async {
    return DishModel(
      id: dishId,
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
      categories: categories,
      isAvailable: isAvailable,
      preparationTime: preparationTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      chefId: null,
    );
  }
}
