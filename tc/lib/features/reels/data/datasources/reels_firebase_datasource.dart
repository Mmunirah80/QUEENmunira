import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../models/reel_model.dart';
import 'reels_remote_datasource.dart';

class ReelsFirebaseDataSource implements ReelsRemoteDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;

  String get _currentUserId => _sb.auth.currentUser?.id ?? '';

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  Future<bool> _isCurrentUserAdmin() async {
    final uid = _currentUserId;
    if (uid.isEmpty) return false;
    final row = await _sb.from('profiles').select('role').eq('id', uid).maybeSingle();
    return (row?['role'] as String?) == 'admin';
  }

  /// Reels are public feed content; same rule as RLS [reels_insert_approved_chef].
  Future<void> _requireApprovedChefForReelsUpload() async {
    final uid = _currentUserId;
    if (uid.isEmpty) throw Exception('Auth error');
    if (await _isCurrentUserAdmin()) return;
    final row = await _sb
        .from('chef_profiles')
        .select('approval_status, suspended')
        .eq('id', uid)
        .maybeSingle();
    if (row == null) {
      throw Exception('Chef profile not found');
    }
    if (row['suspended'] == true) {
      throw Exception('Your kitchen is suspended. You cannot post reels.');
    }
    if ((row['approval_status']?.toString() ?? '') != 'approved') {
      throw Exception(
        'Your account must be approved before you can post reels. Complete verification in Profile → Documents.',
      );
    }
  }

  Future<Map<String, String>> _fetchKitchenNames(List<String> chefIds) async {
    if (chefIds.isEmpty) return {};
    final res = await _sb.from('chef_profiles').select('id,kitchen_name').inFilter('id', chefIds);
    final map = <String, String>{};
    for (final raw in (res as List)) {
      final row = raw as Map<String, dynamic>;
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = (row['kitchen_name'] as String?)?.trim().isNotEmpty == true
          ? (row['kitchen_name'] as String).trim()
          : 'Cook';
    }
    return map;
  }

  Future<Map<String, String>> _fetchDishNames(List<String> dishIds) async {
    if (dishIds.isEmpty) return {};
    final res = await _sb.from('menu_items').select('id,name').inFilter('id', dishIds);
    final map = <String, String>{};
    for (final raw in (res as List)) {
      final row = raw as Map<String, dynamic>;
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = (row['name'] as String?) ?? '';
    }
    return map;
  }

  Future<List<ReelModel>> _mapRows(
    List<dynamic> rows, {
    required String currentUserId,
  }) async {
    final reelIds = rows
        .map((e) => (e as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final chefIds = rows
        .map((e) => (e as Map<String, dynamic>)['chef_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final dishIds = rows
        .map((e) => (e as Map<String, dynamic>)['dish_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final kitchenNames = await _fetchKitchenNames(chefIds);
    final dishNames = await _fetchDishNames(dishIds);

    final likesByReel = <String, int>{};
    final likedByMe = <String>{};
    if (reelIds.isNotEmpty) {
      final likesRows = await _sb
          .from('reel_likes')
          .select('reel_id,customer_id')
          .inFilter('reel_id', reelIds);
      for (final raw in (likesRows as List)) {
        final row = raw as Map<String, dynamic>;
        final reelId = (row['reel_id'] ?? '').toString();
        final liker = (row['customer_id'] ?? '').toString();
        if (reelId.isEmpty) continue;
        likesByReel[reelId] = (likesByReel[reelId] ?? 0) + 1;
        if (currentUserId.isNotEmpty && liker == currentUserId) {
          likedByMe.add(reelId);
        }
      }
    }

    return rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      final id = (row['id'] ?? '').toString();
      final chefId = (row['chef_id'] ?? '').toString();
      final dishId = row['dish_id']?.toString();
      final chefName = kitchenNames[chefId] ?? ((row['chef_name'] ?? row['chefName']) ?? 'Cook').toString();
      return ReelModel(
        id: id,
        chefId: chefId,
        chefName: chefName,
        kitchenName: chefName,
        videoUrl: ((row['video_url'] ?? row['videoUrl']) ?? '').toString(),
        thumbnailUrl: row['thumbnail_url']?.toString(),
        description: ((row['caption'] ?? row['description']) ?? '').toString(),
        dishId: dishId != null && dishId.isNotEmpty ? dishId : null,
        dishName: dishId != null && dishId.isNotEmpty ? dishNames[dishId] : null,
        tags: _parseTags(row['tags']),
        likesCount: likesByReel[id] ?? 0,
        likedBy: const [],
        commentsCount: 0,
        createdAt: _parseDate(row['created_at']),
        isLiked: likedByMe.contains(id),
      );
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<ReelModel>> getReels() async {
    final userId = _currentUserId;
    final rows = await _sb
        .from('reels')
        .select()
        .order('created_at', ascending: false);
    return _mapRows((rows as List?) ?? const [], currentUserId: userId);
  }

  @override
  Future<List<ReelModel>> getMyReels() async {
    final uid = _currentUserId;
    if (uid.isEmpty) return [];
    return getReelsByCook(uid);
  }

  @override
  Future<List<ReelModel>> getReelsByCook(String cookId) async {
    if (cookId.isEmpty) return [];
    final rows =
        await _sb.from('reels').select().eq('chef_id', cookId).order('created_at', ascending: false);
    return _mapRows((rows as List?) ?? const [], currentUserId: _currentUserId);
  }

  @override
  Stream<List<ReelModel>> streamReels({String? currentUserId}) {
    final userId = currentUserId ?? _currentUserId;
    return _sb
        .from('reels')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((rows) => _mapRows(rows, currentUserId: userId));
  }

  @override
  Stream<List<ReelModel>> streamMyReels(String chefId, {String? currentUserId}) {
    if (chefId.isEmpty) return Stream.value(const []);
    return _sb
        .from('reels')
        .stream(primaryKey: ['id'])
        .eq('chef_id', chefId)
        .order('created_at', ascending: false)
        .asyncMap((rows) => _mapRows(rows, currentUserId: currentUserId ?? _currentUserId));
  }

  @override
  Future<List<ReelModel>> searchReelsByTag(String tag, {String? currentUserId}) async {
    final reels = await getReels();
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) return reels;
    return reels
        .where((r) =>
            r.tags.any((x) => x.toLowerCase().contains(t)) ||
            (r.description ?? '').toLowerCase().contains(t))
        .toList();
  }

  @override
  Future<ReelModel> uploadReel({
    required String videoUrl,
    String? caption,
  }) async {
    final cookId = _currentUserId;
    if (cookId.isEmpty) throw Exception('Auth error');
    await _requireApprovedChefForReelsUpload();
    final row = await _sb
        .from('reels')
        .insert({
          'chef_id': cookId,
          'video_url': videoUrl,
          'caption': caption ?? '',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return ReelModel(
      id: (row['id'] ?? '').toString(),
      chefId: cookId,
      chefName: 'Cook',
      videoUrl: videoUrl,
      thumbnailUrl: null,
      description: caption ?? '',
      tags: const [],
      likesCount: 0,
      likedBy: const [],
      commentsCount: 0,
      createdAt: _parseDate(row['created_at']),
      isLiked: false,
    );
  }

  @override
  Future<ReelModel> uploadReelFromFile(
    File videoFile, {
    required String description,
    required List<String> tags,
    String? dishId,
  }) async {
    final cookId = _currentUserId;
    if (cookId.isEmpty) throw Exception('Auth error');
    await _requireApprovedChefForReelsUpload();

    String? linkedDishId = dishId?.trim();
    if (linkedDishId != null && linkedDishId.isEmpty) linkedDishId = null;
    if (linkedDishId != null) {
      final dish = await _sb.from('menu_items').select('chef_id,name').eq('id', linkedDishId).maybeSingle();
      if (dish == null || (dish['chef_id']?.toString() ?? '') != cookId) {
        throw Exception('Pick a dish from your own menu');
      }
    }

    final ext = videoFile.path.contains('.')
        ? videoFile.path.split('.').last.toLowerCase()
        : 'mp4';
    final path = '$cookId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _sb.storage.from('reels').upload(path, videoFile, fileOptions: const FileOptions(upsert: true));
    final url = _sb.storage.from('reels').getPublicUrl(path);

    String? thumbnailUrl;
    try {
      final tmpDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tmpDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
      );
      if (thumbPath != null) {
        final thumbFile = File(thumbPath);
        final thumbStoragePath = '$cookId/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _sb.storage.from('reels').upload(thumbStoragePath, thumbFile, fileOptions: const FileOptions(upsert: true));
        thumbnailUrl = _sb.storage.from('reels').getPublicUrl(thumbStoragePath);
      }
    } catch (_) {
      // Thumbnail is optional; video still uploads.
    }

    return _insertReelRow(
      cookId: cookId,
      videoUrl: url,
      thumbnailUrl: thumbnailUrl,
      description: description,
      tags: tags,
      linkedDishId: linkedDishId,
    );
  }

  @override
  Future<ReelModel> uploadReelFromBytes(
    Uint8List videoBytes, {
    required String filename,
    required String description,
    required List<String> tags,
    String? dishId,
  }) async {
    final cookId = _currentUserId;
    if (cookId.isEmpty) throw Exception('Auth error');
    await _requireApprovedChefForReelsUpload();

    String? linkedDishId = dishId?.trim();
    if (linkedDishId != null && linkedDishId.isEmpty) linkedDishId = null;
    if (linkedDishId != null) {
      final dish = await _sb.from('menu_items').select('chef_id,name').eq('id', linkedDishId).maybeSingle();
      if (dish == null || (dish['chef_id']?.toString() ?? '') != cookId) {
        throw Exception('Pick a dish from your own menu');
      }
    }

    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'mp4';
    final path = '$cookId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _sb.storage.from('reels').uploadBinary(path, videoBytes, fileOptions: const FileOptions(upsert: true));
    final url = _sb.storage.from('reels').getPublicUrl(path);

    return _insertReelRow(
      cookId: cookId,
      videoUrl: url,
      thumbnailUrl: null,
      description: description,
      tags: tags,
      linkedDishId: linkedDishId,
    );
  }

  Future<ReelModel> _insertReelRow({
    required String cookId,
    required String videoUrl,
    required String description,
    required List<String> tags,
    String? linkedDishId,
    String? thumbnailUrl,
  }) async {
    final insertPayload = <String, dynamic>{
      'chef_id': cookId,
      'video_url': videoUrl,
      'caption': description,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (tags.isNotEmpty) insertPayload['tags'] = tags;
    if (linkedDishId != null) insertPayload['dish_id'] = linkedDishId;
    if (thumbnailUrl != null) insertPayload['thumbnail_url'] = thumbnailUrl;

    final inserted = await _sb.from('reels').insert(insertPayload).select().single();

    String? dishName;
    if (linkedDishId != null) {
      final d = await _sb.from('menu_items').select('name').eq('id', linkedDishId).maybeSingle();
      dishName = d?['name'] as String?;
    }

    return ReelModel(
      id: (inserted['id'] ?? '').toString(),
      chefId: cookId,
      chefName: 'Cook',
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      description: description,
      dishId: linkedDishId,
      dishName: dishName,
      tags: tags,
      likesCount: 0,
      likedBy: const [],
      commentsCount: 0,
      createdAt: _parseDate(inserted['created_at']),
      isLiked: false,
    );
  }

  @override
  Future<void> likeReel(String reelId) async {
    final userId = _currentUserId;
    if (userId.isEmpty || reelId.isEmpty) return;
    await _sb.from('reel_likes').upsert({
      'reel_id': reelId,
      'customer_id': userId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> unlikeReel(String reelId) async {
    final userId = _currentUserId;
    if (userId.isEmpty || reelId.isEmpty) return;
    await _sb
        .from('reel_likes')
        .delete()
        .eq('reel_id', reelId)
        .eq('customer_id', userId);
  }

  @override
  Future<void> deleteReel(String reelId) async {
    if (reelId.isEmpty) return;
    final cookId = _currentUserId;
    final row = await _sb
        .from('reels')
        .select('video_url,thumbnail_url,chef_id')
        .eq('id', reelId)
        .maybeSingle();
    if (row == null) return;
    final ownerId = row['chef_id']?.toString() ?? '';
    final isAdmin = await _isCurrentUserAdmin();
    if (cookId.isNotEmpty && ownerId != cookId && !isAdmin) {
      throw Exception('Auth error');
    }
    if (cookId.isEmpty && !isAdmin) {
      throw Exception('Auth error');
    }
    final videoUrl = row['video_url']?.toString() ?? '';
    final thumbUrl = row['thumbnail_url']?.toString() ?? '';
    await _sb.from('reel_likes').delete().eq('reel_id', reelId);
    await _sb.from('reels').delete().eq('id', reelId);
    final marker = '/storage/v1/object/public/reels/';
    final paths = <String>[];
    for (final u in [videoUrl, thumbUrl]) {
      if (u.contains(marker)) {
        final objectPath = u.split(marker).last;
        if (objectPath.isNotEmpty) paths.add(objectPath);
      }
    }
    if (paths.isNotEmpty) {
      await _sb.storage.from('reels').remove(paths.toSet().toList());
    }
  }
}
