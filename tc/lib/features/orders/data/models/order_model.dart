import '../../domain/entities/order_entity.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    super.customerId,
    required super.customerName,
    super.customerImageUrl,
    super.chefId,
    super.chefName,
    required super.items,
    required super.totalAmount,
    super.commissionAmount,
    required super.status,
    super.dbStatus,
    super.cancelReason,
    required super.createdAt,
    super.deliveryAddress,
    super.notes,
    super.idempotencyKey,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String? ?? 'Customer',
      customerImageUrl: json['customerImageUrl'] as String?,
      chefId: json['chefId'] as String?,
      chefName: json['chefName'] as String?,
      items: (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == 'OrderStatus.${json['status']}',
        orElse: () => OrderStatus.pending,
      ),
      dbStatus: json['dbStatus'] as String?,
      cancelReason: json['cancelReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deliveryAddress: json['deliveryAddress'] as String?,
      notes: json['notes'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerImageUrl': customerImageUrl,
      'chefId': chefId,
      'chefName': chefName,
      'items': items.map((item) => (item as OrderItemModel).toJson()).toList(),
      'totalAmount': totalAmount,
      if (commissionAmount != null) 'commissionAmount': commissionAmount,
      'status': status.toString().split('.').last,
      if (dbStatus != null) 'dbStatus': dbStatus,
      if (cancelReason != null) 'cancelReason': cancelReason,
      'createdAt': createdAt.toIso8601String(),
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }
}

class OrderItemModel extends OrderItemEntity {
  const OrderItemModel({
    required super.id,
    required super.dishName,
    required super.quantity,
    required super.price,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      dishName: json['dishName'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dishName': dishName,
      'quantity': quantity,
      'price': price,
    };
  }
}
