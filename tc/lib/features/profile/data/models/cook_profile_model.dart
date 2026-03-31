import '../../domain/entities/cook_profile_entity.dart';

class CookProfileModel extends CookProfileEntity {
  const CookProfileModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    super.profileImageUrl,
    super.bio,
    super.rating,
    super.totalOrders,
    super.totalReviews,
    super.isVerified,
    super.joinedDate,
  });

  factory CookProfileModel.fromJson(Map<String, dynamic> json) {
    return CookProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      bio: json['bio'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalOrders: json['totalOrders'] as int? ?? 0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      joinedDate: json['joinedDate'] != null
          ? DateTime.parse(json['joinedDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'rating': rating,
      'totalOrders': totalOrders,
      'totalReviews': totalReviews,
      'isVerified': isVerified,
      'joinedDate': joinedDate?.toIso8601String(),
    };
  }
}
