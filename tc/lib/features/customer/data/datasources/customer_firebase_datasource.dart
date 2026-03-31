import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_config.dart';

/// Supabase access for customer data: favorites, addresses, notifications, profile.
class CustomerFirebaseDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;
  static final Set<String> _inFlightWrites = <String>{};

  Future<T?> _guardedWrite<T>(String lockKey, Future<T> Function() action) async {
    if (_inFlightWrites.contains(lockKey)) return null;
    _inFlightWrites.add(lockKey);
    try {
      return await action();
    } catch (e, st) {
      debugPrint('[CustomerFirebaseDataSource] write error ($lockKey): $e');
      debugPrint('[CustomerFirebaseDataSource] stackTrace: $st');
      rethrow;
    } finally {
      _inFlightWrites.remove(lockKey);
    }
  }

  // ─── Favorites ──────────────────────────────────────────────

  Stream<List<String>> watchFavoriteDishIds(String uid) {
    return _sb
        .from('favorites')
        .stream(primaryKey: ['id'])
        .eq('customer_id', uid)
        .map((rows) => rows.map<String>((r) => r['item_id'] as String).toList());
  }

  Future<void> addFavorite(String uid, String dishId) async {
    await _guardedWrite<void>('fav_add:$uid:$dishId', () async {
      await _sb.from('favorites').upsert({
        'customer_id': uid,
        'item_id': dishId,
      });
    });
  }

  Future<void> removeFavorite(String uid, String dishId) async {
    await _guardedWrite<void>('fav_remove:$uid:$dishId', () async {
      await _sb.from('favorites').delete().eq('customer_id', uid).eq('item_id', dishId);
    });
  }

  Future<bool> isFavorite(String uid, String dishId) async {
    final result = await _sb
        .from('favorites')
        .select('id')
        .eq('customer_id', uid)
        .eq('item_id', dishId)
        .maybeSingle();
    return result != null;
  }

  // ─── Addresses ──────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchAddresses(String uid) {
    return _sb
        .from('addresses')
        .stream(primaryKey: ['id'])
        .eq('customer_id', uid)
        .map((rows) => rows.map<Map<String, dynamic>>((r) => {
              'id': r['id'],
              'label': r['label'] ?? '',
              'street': r['street'] ?? '',
              'city': r['city'],
              'district': r['district'],
              'phone': r['phone'],
              'isDefault': r['is_default'] ?? false,
            }).toList());
  }

  Future<String> addAddress(
    String uid, {
    required String label,
    required String street,
    String? city,
    String? phone,
    bool isDefault = false,
  }) async {
    final result = await _guardedWrite<Map<String, dynamic>>('addr_add:$uid:$label:$street', () async {
      if (isDefault) {
        await _sb.from('addresses').update({'is_default': false}).eq('customer_id', uid);
      }
      return await _sb.from('addresses').insert({
        'customer_id': uid,
        'label': label,
        'street': street,
        'city': city,
        'is_default': isDefault,
      }).select('id').single();
    });
    return result?['id'] as String? ?? '';
  }

  Future<void> updateAddress(
    String uid,
    String addressId, {
    String? label,
    String? street,
    String? city,
    String? phone,
    bool? isDefault,
  }) async {
    await _guardedWrite<void>('addr_update:$uid:$addressId', () async {
      if (isDefault == true) {
        await _sb.from('addresses').update({'is_default': false}).eq('customer_id', uid);
      }
      final updates = <String, dynamic>{};
      if (label != null) updates['label'] = label;
      if (street != null) updates['street'] = street;
      if (city != null) updates['city'] = city;
      if (isDefault != null) updates['is_default'] = isDefault;
      if (updates.isNotEmpty) {
        await _sb.from('addresses').update(updates).eq('id', addressId).eq('customer_id', uid);
      }
    });
  }

  Future<void> setDefaultAddress(String uid, String addressId) async {
    await _guardedWrite<void>('addr_default:$uid:$addressId', () async {
      await _sb.from('addresses').update({'is_default': false}).eq('customer_id', uid);
      await _sb.from('addresses').update({'is_default': true}).eq('id', addressId).eq('customer_id', uid);
    });
  }

  Future<void> deleteAddress(String uid, String addressId) async {
    await _guardedWrite<void>('addr_delete:$uid:$addressId', () async {
      await _sb.from('addresses').delete().eq('id', addressId).eq('customer_id', uid);
    });
  }

  // ─── Notifications ──────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchNotifications(String uid) {
    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('customer_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.map<Map<String, dynamic>>((r) => {
              'id': r['id'],
              'title': r['title'] ?? '',
              'body': r['body'] ?? '',
              'read': r['is_read'] ?? false,
              'type': r['type'],
              'data': r['data'],
              'createdAt': r['created_at'] ?? '',
            }).toList());
  }

  Future<void> markNotificationRead(String uid, String notificationId) async {
    await _guardedWrite<void>('notif_read:$uid:$notificationId', () async {
      await _sb.from('notifications').update({'is_read': true}).eq('id', notificationId).eq('customer_id', uid);
    });
  }

  Future<void> markAllNotificationsRead(String uid) async {
    await _guardedWrite<void>('notif_read_all:$uid', () async {
      await _sb.from('notifications').update({'is_read': true}).eq('customer_id', uid).eq('is_read', false);
    });
  }

  // ─── Profile ────────────────────────────────────────────────

  Future<void> updateCustomerProfile(
    String uid, {
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    await _guardedWrite<void>('profile_update:$uid', () async {
      final updates = <String, dynamic>{};
      if (name != null) updates['full_name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      if (updates.isNotEmpty) {
        await _sb.from('profiles').update(updates).eq('id', uid);
      }
    });
  }

  Future<String> uploadProfilePhoto(String uid, File file) async {
    final url = await _guardedWrite<String>('profile_upload:$uid', () async {
      final ext = file.path.split('.').last;
      final path = 'profiles/$uid/avatar.$ext';
      await _sb.storage.from('avatars').upload(path, file, fileOptions: const FileOptions(upsert: true));
      return _sb.storage.from('avatars').getPublicUrl(path);
    });
    return url ?? '';
  }
}