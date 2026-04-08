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
  final String? customerId;
  final String customerName;
  final String? customerImageUrl;
  final String? chefId;
  final String? chefName;
  final List<OrderItemEntity> items;
  final double totalAmount;
  /// Stored commission (from `orders.commission_amount`); null if column absent in row.
  final double? commissionAmount;
  final OrderStatus status;
  /// Raw `orders.status` from Postgres (e.g. `cancelled` or legacy `cancelled_by_system`).
  final String? dbStatus;
  /// Internal `orders.cancel_reason` (never show raw strings to customers; use [OrderDbStatus] mappers).
  final String? cancelReason;
  final DateTime createdAt;
  final String? deliveryAddress;
  final String? notes;
  /// Client idempotency key from `orders.idempotency_key` when present.
  final String? idempotencyKey;

  const OrderEntity({
    required this.id,
    this.customerId,
    required this.customerName,
    this.customerImageUrl,
    this.chefId,
    this.chefName,
    required this.items,
    required this.totalAmount,
    this.commissionAmount,
    required this.status,
    this.dbStatus,
    this.cancelReason,
    required this.createdAt,
    this.deliveryAddress,
    this.notes,
    this.idempotencyKey,
  });

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerImageUrl,
        chefId,
        chefName,
        items,
        totalAmount,
        commissionAmount,
        status,
        dbStatus,
        cancelReason,
        createdAt,
        deliveryAddress,
        notes,
        idempotencyKey,
      ];
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
