import 'dart:io';
import 'dart:typed_data';

import '../models/reel_model.dart';

abstract class ReelsRemoteDataSource {
  Future<List<ReelModel>> getReels();
  Future<List<ReelModel>> getMyReels();
  Future<List<ReelModel>> getReelsByCook(String cookId);
  Stream<List<ReelModel>> streamReels({String? currentUserId});
  Stream<List<ReelModel>> streamMyReels(String chefId, {String? currentUserId});
  Future<List<ReelModel>> searchReelsByTag(String tag, {String? currentUserId});
  Future<ReelModel> uploadReel({
    required String videoUrl,
    String? caption,
  });
  Future<ReelModel> uploadReelFromFile(
    File videoFile, {
    required String description,
    required List<String> tags,
    String? dishId,
  });
  Future<ReelModel> uploadReelFromBytes(
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
