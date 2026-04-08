import '../../domain/entities/reel_entity.dart';

class ReelModel extends ReelEntity {
  const ReelModel({
    required super.id,
    required super.chefId,
    required super.chefName,
    super.kitchenName,
    super.cookImageUrl,
    required super.videoUrl,
    super.thumbnailUrl,
    super.description,
    super.dishId,
    super.dishName,
    super.tags,
    super.likesCount,
    super.likedBy,
    super.commentsCount,
    required super.createdAt,
    super.isLiked,
    super.chefOrderingDisabled = false,
  });

  /// Builds from a map (e.g. Supabase row or JSON). [id] required if not in data. [currentUserId] used to set [isLiked].
  factory ReelModel.fromFirestore(
    Map<String, dynamic> data, {
    String? id,
    String? currentUserId,
  }) {
    final docId = id ?? data['id'] as String? ?? '';
    final chefId = data['chefId'] as String? ?? '';
    final chefName = data['chefName'] as String? ?? '';
    final kitchenName = data['kitchenName'] as String?;
    final videoUrl = data['videoUrl'] as String? ?? '';
    final thumbnailUrl = data['thumbnailUrl'] as String?;
    final description = data['description'] as String?;
    final dishId = data['dishId'] as String? ?? data['dish_id'] as String?;
    final dishName = data['dishName'] as String? ?? data['dish_name'] as String?;
    final tags = (data['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final likedBy = (data['likedBy'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final likesCount = data['likes'] as int? ?? likedBy.length;
    final createdAt = _parseCreatedAt(data['createdAt']);
    final isLiked = currentUserId != null && currentUserId.isNotEmpty && likedBy.contains(currentUserId);

    return ReelModel(
      id: docId,
      chefId: chefId,
      chefName: chefName,
      kitchenName: kitchenName,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      description: description,
      dishId: dishId,
      dishName: dishName,
      tags: tags,
      likesCount: likesCount,
      likedBy: likedBy,
      createdAt: createdAt,
      isLiked: isLiked,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chefId': chefId,
      'chefName': chefName,
      'kitchenName': kitchenName,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'dishId': dishId,
      'dishName': dishName,
      'tags': tags,
      'likes': likesCount,
      'likedBy': likedBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is Map && value['_seconds'] != null) {
      final sec = value['_seconds'] is int ? value['_seconds'] as int : (value['_seconds'] as num).toInt();
      return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }
    return DateTime.now();
  }

  /// Legacy JSON (e.g. mock): cookId/cookName/caption.
  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id'] as String,
      chefId: json['chefId'] as String? ?? json['cookId'] as String,
      chefName: json['chefName'] as String? ?? json['cookName'] as String,
      kitchenName: json['kitchenName'] as String?,
      cookImageUrl: json['cookImageUrl'] as String?,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      description: json['description'] as String? ?? json['caption'] as String?,
      dishId: json['dishId'] as String? ?? json['dish_id'] as String?,
      dishName: json['dishName'] as String? ?? json['dish_name'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      likesCount: json['likes'] as int? ?? json['likesCount'] as int? ?? 0,
      likedBy: (json['likedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      commentsCount: json['commentsCount'] as int? ?? 0,
      createdAt: ReelModel._parseCreatedAt(json['createdAt']),
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chefId': chefId,
      'chefName': chefName,
      'kitchenName': kitchenName,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'dishId': dishId,
      'dishName': dishName,
      'tags': tags,
      'likes': likesCount,
      'likedBy': likedBy,
      'createdAt': createdAt.toIso8601String(),
      'isLiked': isLiked,
    };
  }
}
