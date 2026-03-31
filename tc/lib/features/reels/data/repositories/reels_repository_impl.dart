import 'dart:io';
import 'dart:typed_data';

import '../../domain/entities/reel_entity.dart';
import '../../domain/repositories/reels_repository.dart';
import '../datasources/reels_firebase_datasource.dart';
import '../datasources/reels_remote_datasource.dart';

class ReelsRepositoryImpl implements ReelsRepository {
  final ReelsRemoteDataSource remoteDataSource;

  ReelsRepositoryImpl({
    ReelsRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? ReelsFirebaseDataSource();

  @override
  Future<List<ReelEntity>> getReels() async {
    try {
      final reels = await remoteDataSource.getReels();
      return reels;
    } catch (e) {
      throw Exception('Failed to get reels: ${e.toString()}');
    }
  }

  @override
  Future<List<ReelEntity>> getMyReels() async {
    try {
      final reels = await remoteDataSource.getMyReels();
      return reels;
    } catch (e) {
      throw Exception('Failed to get my reels: ${e.toString()}');
    }
  }

  @override
  Future<List<ReelEntity>> getReelsByCook(String cookId) async {
    try {
      final reels = await remoteDataSource.getReelsByCook(cookId);
      return reels;
    } catch (e) {
      throw Exception('Failed to get reels by cook: ${e.toString()}');
    }
  }

  @override
  Future<ReelEntity> uploadReel({
    required String videoUrl,
    String? caption,
  }) async {
    try {
      final reel = await remoteDataSource.uploadReel(
        videoUrl: videoUrl,
        caption: caption,
      );
      return reel;
    } catch (e) {
      throw Exception('Failed to upload reel: ${e.toString()}');
    }
  }

  @override
  Future<void> likeReel(String reelId) async {
    try {
      await remoteDataSource.likeReel(reelId);
    } catch (e) {
      throw Exception('Failed to like reel: ${e.toString()}');
    }
  }

  @override
  Future<void> unlikeReel(String reelId) async {
    try {
      await remoteDataSource.unlikeReel(reelId);
    } catch (e) {
      throw Exception('Failed to unlike reel: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteReel(String reelId) async {
    try {
      await remoteDataSource.deleteReel(reelId);
    } catch (e) {
      throw Exception('Failed to delete reel: ${e.toString()}');
    }
  }

  @override
  Stream<List<ReelEntity>> streamReels({String? currentUserId}) {
    return remoteDataSource.streamReels(currentUserId: currentUserId);
  }

  @override
  Stream<List<ReelEntity>> streamMyReels(String chefId, {String? currentUserId}) {
    return remoteDataSource.streamMyReels(chefId, currentUserId: currentUserId);
  }

  @override
  Future<List<ReelEntity>> searchReelsByTag(String tag, {String? currentUserId}) async {
    try {
      return await remoteDataSource.searchReelsByTag(tag, currentUserId: currentUserId);
    } catch (e) {
      throw Exception('Failed to search reels: ${e.toString()}');
    }
  }

  @override
  Future<ReelEntity> uploadReelFromFile(
    File videoFile, {
    required String description,
    required List<String> tags,
    String? dishId,
  }) async {
    try {
      return await remoteDataSource.uploadReelFromFile(
        videoFile,
        description: description,
        tags: tags,
        dishId: dishId,
      );
    } catch (e) {
      throw Exception('Failed to upload reel: ${e.toString()}');
    }
  }

  @override
  Future<ReelEntity> uploadReelFromBytes(
    Uint8List videoBytes, {
    required String filename,
    required String description,
    required List<String> tags,
    String? dishId,
  }) async {
    try {
      return await remoteDataSource.uploadReelFromBytes(
        videoBytes,
        filename: filename,
        description: description,
        tags: tags,
        dishId: dishId,
      );
    } catch (e) {
      throw Exception('Failed to upload reel: ${e.toString()}');
    }
  }
}
