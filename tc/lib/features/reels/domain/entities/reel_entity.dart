import 'package:equatable/equatable.dart';

class ReelEntity extends Equatable {
  final String id;
  /// Chef ID (same as cookId for backward compatibility).
  final String chefId;
  final String chefName;
  final String? kitchenName;
  final String? cookImageUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? description;
  /// Optional menu item this reel promotes (order flow).
  final String? dishId;
  final String? dishName;
  final List<String> tags;
  final int likesCount;
  final List<String> likedBy;
  final int commentsCount;
  final DateTime createdAt;
  final bool isLiked;

  const ReelEntity({
    required this.id,
    required this.chefId,
    required this.chefName,
    this.kitchenName,
    this.cookImageUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    this.description,
    this.dishId,
    this.dishName,
    this.tags = const [],
    this.likesCount = 0,
    this.likedBy = const [],
    this.commentsCount = 0,
    required this.createdAt,
    this.isLiked = false,
  });

  /// Backward compatibility: cookId = chefId.
  String get cookId => chefId;
  /// Backward compatibility: cookName = chefName.
  String get cookName => chefName;
  /// Backward compatibility: caption = description.
  String? get caption => description;

  @override
  List<Object?> get props => [
        id,
        chefId,
        chefName,
        kitchenName,
        cookImageUrl,
        videoUrl,
        thumbnailUrl,
        description,
        dishId,
        dishName,
        tags,
        likesCount,
        likedBy,
        commentsCount,
        createdAt,
        isLiked,
      ];
}
