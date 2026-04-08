import 'package:equatable/equatable.dart';

class DishEntity extends Equatable {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final List<String> categories;
  final bool isAvailable;
  /// Matches `menu_items.daily_quantity` (planned portions for the day), same as cook menu — not clock minutes.
  final int preparationTime;
  /// Remaining quantity for this dish for the current day/capacity window.
  /// Used by customers to prevent ordering beyond Cook's daily capacity.
  final int remainingQuantity;
  final DateTime createdAt;
  final DateTime? updatedAt;
  /// Chef who owns this dish (for customer: add to cart / place order).
  final String? chefId;

  const DishEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.categories = const [],
    this.isAvailable = true,
    this.preparationTime = 30,
    this.remainingQuantity = 0,
    required this.createdAt,
    this.updatedAt,
    this.chefId,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        price,
        imageUrl,
        categories,
        isAvailable,
        preparationTime,
        remainingQuantity,
        createdAt,
        updatedAt,
        chefId,
      ];
}
