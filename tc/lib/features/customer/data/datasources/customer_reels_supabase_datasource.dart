// ============================================================
// Customer Reels — Supabase reels + reel_likes.
// Tables: reels (id, chef_id, video_url, thumbnail_url, caption, tags, dish_id, created_at)
//         reel_likes (id, reel_id, customer_id, created_at), UNIQUE(reel_id, customer_id)
// Optional: reels.likes_count maintained by supabase_reels_likes_count_v1.sql (Realtime on reels).
// Chef name from chef_profiles.kitchen_name where id = chef_id.
// Location: ONLY [CustomerPickupOrigin] (GPS/map pin → geocode). Geographic “region” matches Home
// city/radius ([chefReelGeographyMatches] / [buildHomeSortedChefsForReels]) — kitchen_city + pin, not
// profiles.city. Chef standing for reels: [chefReelAccountEligibleForPublicFeed] (approved, not
// suspended, not frozen). Reel row: is_active, deleted_at null, not is_hidden.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/location/pickup_distance.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../cook/data/models/chef_doc_model.dart';
import '../../../reels/domain/entities/reel_entity.dart';
import '../../../reels/domain/reel_public_feed_visibility.dart';
import '../../domain/customer_reels_pickup_contract.dart';

class CustomerReelsSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.client;
  static final Set<String> _inFlightLikeKeys = <String>{};

  /// Stream reels: same kitchen region as Home ([chefReelGeographyMatches]) + approved/non-frozen chef
  /// ([chefReelVisibleToCustomer]). Not gated on storefront open hours (unlike dish browse).
  ///
  /// Subscribes to both [reels] and [reel_likes] so counts refresh when others like a reel
  /// (even before reels.likes_count trigger is deployed).
  Stream<List<ReelEntity>> watchReels(
    String customerId, {
    /// Same as [CustomerPickupOrigin.localityCity] on Home (reverse-geocoded from the pickup pin).
    String? pickupLocalityCity,
    double? pickupLat,
    double? pickupLng,
  }) {
    if (customerId.isEmpty) {
      return Stream.value(const <ReelEntity>[]);
    }
    if (customerReelsRequirePickupCoordinates(pickupLat, pickupLng)) {
      return Stream.value(const <ReelEntity>[]);
    }
    final lat = pickupLat!;
    final lng = pickupLng!;
    final controller = StreamController<List<ReelEntity>>();
    List<Map<String, dynamic>>? lastRows;

    Future<void> emit() async {
      final rows = lastRows;
      if (rows == null) return;
      try {
        final list = await _enrichReels(
          rows,
          customerId,
          pickupLocalityCity: pickupLocalityCity,
          pickupLat: lat,
          pickupLng: lng,
        );
        if (!controller.isClosed) controller.add(list);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    late final StreamSubscription<dynamic> subReels;
    late final StreamSubscription<dynamic> subLikes;

    subReels = _sb.from('reels').stream(primaryKey: ['id']).listen(
      (rows) {
        lastRows = (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        emit();
      },
      onError: controller.addError,
    );
    subLikes = _sb.from('reel_likes').stream(primaryKey: ['id']).listen(
      (_) => emit(),
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subReels.cancel();
      await subLikes.cancel();
      if (!controller.isClosed) await controller.close();
    };

    return controller.stream;
  }

  List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  Future<List<ReelEntity>> _enrichReels(
    List<Map<String, dynamic>> rows,
    String customerId, {
    String? pickupLocalityCity,
    required double pickupLat,
    required double pickupLng,
  }) async {
    if (rows.isEmpty) return [];

    final rowsFeed = rows.where(isReelRowPublicFeedVisible).toList();
    if (rowsFeed.isEmpty) return [];

    final chefIds = rowsFeed.map((r) => r['chef_id'] as String?).whereType<String>().toSet().toList();

    final Map<String, String> chefNames = {};
    final Map<String, bool> chefOrderingDisabledByChef = {};
    final Map<String, ChefDocModel> chefDocById = {};
    if (chefIds.isNotEmpty) {
      final chefs = await _sb
          .from('chef_profiles')
          .select(
            'id, kitchen_name, kitchen_city, kitchen_latitude, kitchen_longitude, '
            'is_online, vacation_mode, vacation_start, vacation_end, '
            'working_hours_start, working_hours_end, working_hours, '
            'suspended, approval_status, initial_approval_at, access_level, documents_operational_ok, '
            'freeze_until, freeze_type',
          )
          .inFilter('id', chefIds);
      for (final c in chefs as List) {
        final id = c['id'] as String?;
        if (id == null) continue;
        final m = Map<String, dynamic>.from(c as Map);
        chefNames[id] = m['kitchen_name'] as String? ?? 'Cook';
        final doc = ChefDocModel.fromSupabase(m);
        chefDocById[id] = doc;
        chefOrderingDisabledByChef[id] = doc.isFreezeActive;
      }
    }

    final visibleRows = rowsFeed.where((r) {
      final chefId = r['chef_id'] as String? ?? '';
      final doc = chefDocById[chefId];
      if (doc == null) return false;
      return chefReelVisibleToCustomer(doc, pickupLat, pickupLng, pickupLocalityCity);
    }).toList();

    final dishIds = visibleRows.map((r) => r['dish_id'] as String?).whereType<String>().toSet().toList();

    final Map<String, String> dishNames = {};
    if (dishIds.isNotEmpty) {
      final dishes = await _sb.from('menu_items').select('id, name').inFilter('id', dishIds);
      for (final d in dishes as List) {
        final id = d['id'] as String?;
        if (id != null) dishNames[id] = d['name'] as String? ?? '';
      }
    }

    final filteredReelIds = visibleRows.map((r) => r['id'] as String?).whereType<String>().toList();

    final hasLikesCountColumn =
        visibleRows.isNotEmpty && visibleRows.first.containsKey('likes_count');

    final counts = <String, int>{};
    if (!hasLikesCountColumn && filteredReelIds.isNotEmpty) {
      final likes = await _sb.from('reel_likes').select('reel_id').inFilter('reel_id', filteredReelIds);
      for (final raw in likes as List) {
        final row = raw as Map<String, dynamic>;
        final reelId = row['reel_id'] as String?;
        if (reelId == null) continue;
        counts[reelId] = (counts[reelId] ?? 0) + 1;
      }
    }

    final likedByUser = <String>{};
    if (filteredReelIds.isNotEmpty) {
      final mine = await _sb
          .from('reel_likes')
          .select('reel_id')
          .eq('customer_id', customerId)
          .inFilter('reel_id', filteredReelIds);
      for (final raw in mine as List) {
        final row = raw as Map<String, dynamic>;
        final rid = row['reel_id'] as String?;
        if (rid != null) likedByUser.add(rid);
      }
    }

    final list = visibleRows.map((r) {
      final id = r['id'] as String? ?? '';
      final chefId = r['chef_id'] as String? ?? '';
      final chefName = chefNames[chefId] ?? 'Cook';
      final dishId = r['dish_id'] as String?;
      final createdAt = _parseDateTime(r['created_at']) ?? DateTime.now();
      final fromCol = (r['likes_count'] as num?)?.toInt();
      final likesCount = fromCol ?? counts[id] ?? 0;
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
        chefOrderingDisabled: chefOrderingDisabledByChef[chefId] ?? false,
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

  /// Toggle like: if already liked, delete; otherwise upsert on UNIQUE(reel_id, customer_id).
  Future<void> toggleLike(String reelId, String userId) async {
    final lockKey = '$reelId:$userId';
    if (_inFlightLikeKeys.contains(lockKey)) return;
    _inFlightLikeKeys.add(lockKey);
    try {
      final liked = await isLiked(reelId, userId);
      if (liked) {
        await _sb.from('reel_likes').delete().eq('reel_id', reelId).eq('customer_id', userId);
      } else {
        await _sb.from('reel_likes').upsert(
          {
            'reel_id': reelId,
            'customer_id': userId,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'reel_id,customer_id',
        );
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
