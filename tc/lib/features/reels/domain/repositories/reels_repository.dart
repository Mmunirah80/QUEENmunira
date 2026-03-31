import 'dart:io';
import 'dart:typed_data';

import '../entities/reel_entity.dart';

abstract class ReelsRepository {
  Future<List<ReelEntity>> getReels();
  Future<List<ReelEntity>> getMyReels();
  Future<List<ReelEntity>> getReelsByCook(String cookId);
  Stream<List<ReelEntity>> streamReels({String? currentUserId});
  Stream<List<ReelEntity>> streamMyReels(String chefId, {String? currentUserId});
  Future<List<ReelEntity>> searchReelsByTag(String tag, {String? currentUserId});
  Future<ReelEntity> uploadReel({
    required String videoUrl,
    String? caption,
  });
  Future<ReelEntity> uploadReelFromFile(
    File videoFile, {
    required String description,
    required List<String> tags,
    String? dishId,
  });
  Future<ReelEntity> uploadReelFromBytes(
    Uint8List videoBytes, {
    required String filename,
    required String description,
    required List<String> tags,
    String? dishId,
  });
  Future<void> likeReel(String reelId);
  Future<void> unlikeReel(String reelId);
  Future<void> deleteReel(String reelId);
}
