import 'package:equatable/equatable.dart';

class CookProfileEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profileImageUrl;
  final String? bio;
  final double rating;
  final int totalOrders;
  final int totalReviews;
  final bool isVerified;
  final DateTime? joinedDate;

  const CookProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profileImageUrl,
    this.bio,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalReviews = 0,
    this.isVerified = false,
    this.joinedDate,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        profileImageUrl,
        bio,
        rating,
        totalOrders,
        totalReviews,
        isVerified,
        joinedDate,
      ];
}
