// ============================================================
// Customer Reels — Supabase reels + reel_likes.
// Tables: reels (id, chef_id, video_url, thumbnail_url, caption, tags, dish_id, created_at)
//         reel_likes (id, reel_id, customer_id, created_at), UNIQUE(reel_id, customer_id)
// Chef name from chef_profiles.kitchen_name where id = chef_id.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../../reels/domain/entities/reel_entity.dart';

class CustomerReelsSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.client;
  static final Set<String> _inFlightLikeKeys = <String>{};

  /// Stream all reels ordered by created_at desc, with chef name and like counts / isLiked for [customerId].
  Stream<List<ReelEntity>> watchReels(String customerId) {
    return _sb
        .from('reels')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) => _enrichReels(rows, customerId));
  }

  List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  Future<List<ReelEntity>> _enrichReels(List<Map<String, dynamic>> rows, String customerId) async {
    if (rows.isEmpty) return [];
    final reelIds = rows.map((r) => r['id'] as String?).whereType<String>().toList();
    final chefIds = rows.map((r) => r['chef_id'] as String?).whereType<String>().toSet().toList();
    final dishIds = rows.map((r) => r['dish_id'] as String?).whereType<String>().toSet().toList();

    // Fetch chef names from chef_profiles (id = chef_id)
    final Map<String, String> chefNames = {};
    if (chefIds.isNotEmpty) {
      final chefs = await _sb.from('chef_profiles').select('id, kitchen_name').inFilter('id', chefIds);
      for (final c in chefs as List) {
        final id = c['id'] as String?;
        if (id != null) chefNames[id] = c['kitchen_name'] as String? ?? 'Cook';
      }
    }

    final Map<String, String> dishNames = {};
    if (dishIds.isNotEmpty) {
      final dishes = await _sb.from('menu_items').select('id, name').inFilter('id', dishIds);
      for (final d in dishes as List) {
        final id = d['id'] as String?;
        if (id != null) dishNames[id] = d['name'] as String? ?? '';
      }
    }

    // Fetch like counts and whether current user liked
    final List<Map<String, dynamic>> likesRows = [];
    if (reelIds.isNotEmpty) {
      final likes = await _sb.from('reel_likes').select('reel_id, customer_id').inFilter('reel_id', reelIds);
      likesRows.addAll((likes as List).cast<Map<String, dynamic>>());
    }
    final counts = <String, int>{};
    final likedByUser = <String>{};
    for (final r in likesRows) {
      final reelId = r['reel_id'] as String?;
      if (reelId == null) continue;
      counts[reelId] = (counts[reelId] ?? 0) + 1;
      if (r['customer_id'] == customerId) likedByUser.add(reelId);
    }

    final list = rows.map((r) {
      final id = r['id'] as String? ?? '';
      final chefId = r['chef_id'] as String? ?? '';
      final chefName = chefNames[chefId] ?? 'Cook';
      final dishId = r['dish_id'] as String?;
      final createdAt = _parseDateTime(r['created_at']) ?? DateTime.now();
      final likesCount = counts[id] ?? 0;
      final isLiked = likedByUser.contains(id);
      final dId = dishId != null && dishId.isNotEmpty ? dishId : null;
      return ReelEntity(
        id: id,
        chefId: chefId,
        chefName: chefName,
        kitchenName: chefName,
        videoUrl: r['video_url'] as String? ?? '',
        thumbnailUrl: r['thumbnail_url'] as String?,
        description: r['caption'] as String?,
        dishId: dId,
        dishName: dId != null ? dishNames[dId] : null,
        tags: _parseTags(r['tags']),
        likesCount: likesCount,
        likedBy: const [],
        commentsCount: 0,
        createdAt: createdAt,
        isLiked: isLiked,
      );
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Toggle like: if already liked, delete; otherwise insert. [userId] = customer_id.
  Future<void> toggleLike(String reelId, String userId) async {
    print('Reel like: reel=$reelId, user=$userId');
    final lockKey = '$reelId:$userId';
    if (_inFlightLikeKeys.contains(lockKey)) return;
    _inFlightLikeKeys.add(lockKey);
    try {
      final liked = await isLiked(reelId, userId);
      if (liked) {
        await _sb.from('reel_likes').delete().eq('reel_id', reelId).eq('customer_id', userId);
      } else {
        await _sb.from('reel_likes').insert({
          'id': const Uuid().v4(),
          'reel_id': reelId,
          'customer_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e, st) {
      debugPrint('[CustomerReels] toggleLike error: $e');
      debugPrint('[CustomerReels] toggleLike stackTrace: $st');
      rethrow;
    } finally {
      _inFlightLikeKeys.remove(lockKey);
    }
  }

  /// Returns true if [userId] has liked [reelId].
  Future<bool> isLiked(String reelId, String userId) async {
    final row = await _sb
        .from('reel_likes')
        .select('id')
        .eq('reel_id', reelId)
        .eq('customer_id', userId)
        .maybeSingle();
    return row != null;
  }

  /// Stream of reel ids that [customerId] has liked (for reactive like state).
  Stream<Set<String>> watchLikedReelIds(String customerId) {
    return _sb
        .from('reel_likes')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .map((rows) => rows
            .map((r) => r['reel_id'] as String?)
            .whereType<String>()
            .toSet());
  }
}
