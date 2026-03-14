import 'order_entity.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.customerName,
    super.customerImageUrl,
    required super.items,
    required super.totalAmount,
    required super.status,
    required super.createdAt,
    super.deliveryAddress,
    super.notes,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      customerName: json['customerName'] as String,
      customerImageUrl: json['customerImageUrl'] as String?,
      items: (json['items'] as List?)
              ?.map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: ((json['totalAmount'] ?? 0) as num).toDouble(),
      status: _statusFromString(json['status'] as String?),
      createdAt: _parseDate(json['createdAt']),
      deliveryAddress: json['deliveryAddress'] as String?,
      notes: json['notes'] as String?,
    );
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
      id: json['id'] as String? ?? '',
      dishName: json['dishName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: ((json['price'] ?? 0) as num).toDouble(),
    );
  }
}

OrderStatus _statusFromString(String? s) {
  if (s == null) return OrderStatus.pending;
  return OrderStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => OrderStatus.pending,
  );
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
