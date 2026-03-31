/// In-memory cart item (single dish from one chef).
class CartItemModel {
  final String dishId;
  final String dishName;
  final String chefId;
  final String chefName;
  final double price;
  int quantity;

  CartItemModel({
    required this.dishId,
    required this.dishName,
    required this.chefId,
    required this.chefName,
    required this.price,
    this.quantity = 1,
  });

  double get lineTotal => price * quantity;

  CartItemModel copyWith({int? quantity}) {
    return CartItemModel(
      dishId: dishId,
      dishName: dishName,
      chefId: chefId,
      chefName: chefName,
      price: price,
      quantity: quantity ?? this.quantity,
    );
  }
}
