import 'package:equatable/equatable.dart';

enum OrderStatus {
  pending,
  accepted,
  rejected,
  preparing,
  ready,
  completed,
  cancelled,
}

class OrderEntity extends Equatable {
  final String id;
  final String customerName;
  final String? customerImageUrl;
  final List<OrderItemEntity> items;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String? deliveryAddress;
  final String? notes;

  const OrderEntity({
    required this.id,
    required this.customerName,
    this.customerImageUrl,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.deliveryAddress,
    this.notes,
  });

  @override
  List<Object?> get props => [id, customerName, customerImageUrl, items, totalAmount, status, createdAt, deliveryAddress, notes];
}

class OrderItemEntity extends Equatable {
  final String id;
  final String dishName;
  final int quantity;
  final double price;

  const OrderItemEntity({
    required this.id,
    required this.dishName,
    required this.quantity,
    required this.price,
  });

  @override
  List<Object?> get props => [id, dishName, quantity, price];
}
