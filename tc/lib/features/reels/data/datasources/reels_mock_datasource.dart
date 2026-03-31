import 'dart:io';
import 'dart:math';

import '../../../../core/constants/app_constants.dart';
import '../models/reel_model.dart';
import 'reels_remote_datasource.dart';

class ReelsMockDataSource implements ReelsRemoteDataSource {
  final List<ReelModel> _reels = [];
  final String _currentCookId = 'cook_1';
  final String _currentCookName = 'My Cook Name';

  ReelsMockDataSource() {
    _initializeMockData();
  }

  void _initializeMockData() {
    final cookNames = ['Ahmed', 'Sara', 'Mohammed', 'Fatima'];
    final tagsList = [
      ['حلا', 'حلويات'],
      ['مندي', 'لحوم'],
      ['كيك', 'حلويات'],
      ['شاورما'],
    ];
    for (int i = 0; i < 8; i++) {
      _reels.add(
        ReelModel(
          id: 'reel_$i',
          chefId: i == 0 ? _currentCookId : 'cook_${i + 1}',
          chefName: i == 0 ? _currentCookName : cookNames[i % cookNames.length],
          kitchenName: 'مطبخ ${cookNames[i % cookNames.length]}',
          videoUrl: 'https://example.com/video_$i.mp4',
          description: i % 2 == 0 ? 'Delicious food! #cooking #food' : null,
          tags: tagsList[i % tagsList.length],
          likesCount: Random().nextInt(1000),
          likedBy: [],
          commentsCount: Random().nextInt(100),
          createdAt: DateTime.now().subtract(Duration(hours: i)),
          isLiked: Random().nextBool(),
        ),
      );
    }
  }

  @override
  Future<List<ReelModel>> getReels() async {
    await Future<void>.delayed(AppConstants.mockDelay);
    return List.from(_reels);
  }

  @override
  Future<List<ReelModel>> getMyReels() async {
    await Future<void>.delayed(AppConstants.mockDelay);
    return _reels.where((reel) => reel.cookId == _currentCookId).toList();
  }

  @override
  Future<List<ReelModel>> getReelsByCook(String cookId) async {
    await Future<void>.delayed(AppConstants.mockDelay);
    return _reels.where((reel) => reel.cookId == cookId).toList();
  }

  @override
  Stream<List<ReelModel>> streamReels({String? currentUserId}) {
    return Stream.periodic(AppConstants.mockDelay, (_) => List<ReelModel>.from(_reels)).take(1);
  }

  @override
  Stream<List<ReelModel>> streamMyReels(String chefId, {String? currentUserId}) {
    final list = _reels.where((r) => r.chefId == chefId).toList();
    return Stream.periodic(AppConstants.mockDelay, (_) => list).take(1);
  }

  @override
  Future<List<ReelModel>> searchReelsByTag(String tag, {String? currentUserId}) async {
    await Future<void>.delayed(AppConstants.mockDelay);
    return _reels.where((r) => r.tags.any((t) => t.toLowerCase().contains(tag.toLowerCase()))).toList();
  }

  @override
  Future<ReelModel> uploadReel({
    required String videoUrl,
    String? caption,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final reel = ReelModel(
      id: 'reel_${DateTime.now().millisecondsSinceEpoch}',
      chefId: _currentCookId,
      chefName: _currentCookName,
      kitchenName: 'مطبخي',
      videoUrl: videoUrl,
      description: caption,
      tags: [],
      likesCount: 0,
      likedBy: [],
      commentsCount: 0,
      createdAt: DateTime.now(),
      isLiked: false,
    );
    _reels.insert(0, reel);
    return reel;
  }

  @override
  Future<ReelModel> uploadReelFromFile(
    File videoFile, {
    required String description,
    required List<String> tags,
    String? dishId,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final reel = ReelModel(
      id: 'reel_${DateTime.now().millisecondsSinceEpoch}',
      chefId: _currentCookId,
      chefName: _currentCookName,
      kitchenName: 'مطبخي',
      videoUrl: 'https://example.com/uploaded.mp4',
      description: description,
      dishId: dishId,
      dishName: null,
      tags: tags,
      likesCount: 0,
      likedBy: [],
      commentsCount: 0,
      createdAt: DateTime.now(),
      isLiked: false,
    );
    _reels.insert(0, reel);
    return reel;
  }

  @override
  Future<void> likeReel(String reelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index != -1 && !_reels[index].isLiked) {
      final r = _reels[index];
      _reels[index] = ReelModel(
        id: r.id,
        chefId: r.chefId,
        chefName: r.chefName,
        kitchenName: r.kitchenName,
        videoUrl: r.videoUrl,
        thumbnailUrl: r.thumbnailUrl,
        description: r.description,
        dishId: r.dishId,
        dishName: r.dishName,
        tags: r.tags,
        likesCount: r.likesCount + 1,
        likedBy: [...r.likedBy, 'current_user'],
        commentsCount: r.commentsCount,
        createdAt: r.createdAt,
        isLiked: true,
      );
    }
  }

  @override
  Future<void> unlikeReel(String reelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index != -1 && _reels[index].isLiked) {
      final r = _reels[index];
      _reels[index] = ReelModel(
        id: r.id,
        chefId: r.chefId,
        chefName: r.chefName,
        kitchenName: r.kitchenName,
        videoUrl: r.videoUrl,
        thumbnailUrl: r.thumbnailUrl,
        description: r.description,
        dishId: r.dishId,
        dishName: r.dishName,
        tags: r.tags,
        likesCount: r.likesCount - 1,
        likedBy: r.likedBy.where((e) => e != 'current_user').toList(),
        commentsCount: r.commentsCount,
        createdAt: r.createdAt,
        isLiked: false,
      );
    }
  }

  @override
  Future<void> deleteReel(String reelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _reels.removeWhere((reel) => reel.id == reelId);
  }
}
