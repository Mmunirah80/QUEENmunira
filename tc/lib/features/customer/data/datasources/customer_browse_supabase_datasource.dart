import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/chef/chef_availability.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../menu/domain/entities/dish_entity.dart';
import '../../../cook/data/models/chef_doc_model.dart';
import '../../domain/customer_browse_dish_visibility.dart';
import '../models/cart_item_model.dart';

/// Supabase datasource for dishes + chefs that customers browse.
///
/// Note: we select [freeze_until] but not [freeze_type] so older DBs without
/// `chef_profiles.freeze_type` still load the customer home (type is optional in [ChefDocModel]).
///
/// Table mapping (matches existing Supabase schema):
///   menu_items    → id, chef_id, name, description, price, image_url,
///                   category (single text), daily_quantity, remaining_quantity,
///                   is_available, created_at
///   chef_profiles → id, kitchen_name, is_online, vacation_mode, vacation_start/end,
///                   working_hours_start, working_hours_end, working_hours (jsonb),
///                   bank_iban, bank_account_name
class CustomerBrowseSupabaseDatasource {
  SupabaseClient get _sb => SupabaseConfig.client;

  /// Account gate for customer-facing menus (must match
  /// `chef_profile_allows_customer_order` in `supabase_naham_marketplace_integrity_final_v1.sql`,
  /// excluding vacation/online/freeze — those are layered via [ChefStorefrontEvaluation] and the batch RPC).
  static bool storefrontAccountAllowsListings(Map<String, dynamic> profile) {
    final suspended = profile['suspended'] as bool? ?? false;
    if (suspended) return false;
    final al = (profile['access_level'] ?? '').toString().toLowerCase();
    if (al == 'full_access') {
      return profile['documents_operational_ok'] as bool? ?? false;
    }
    final approval = (profile['approval_status']?.toString() ?? '').toLowerCase();
    return approval == 'approved';
  }

  /// SECURITY DEFINER batch RPC: blocked chefs, vacation/freeze/online, and account gate (authoritative).
  Future<Map<String, bool>> fetchChefOrderableBatch(Set<String> chefIds) async {
    final uniq = chefIds.where((e) => e.trim().isNotEmpty).toList();
    if (uniq.isEmpty) return {};
    try {
      final res = await _sb.rpc<dynamic>(
        'chef_orderable_for_customers_batch',
        params: {'p_chef_ids': uniq},
      );
      final out = <String, bool>{};
      if (res is List) {
        for (final raw in res) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final id = m['chef_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          out[id] = m['ok'] == true;
        }
      }
      for (final id in uniq) {
        out.putIfAbsent(id, () => false);
      }
      return out;
    } catch (e, st) {
      debugPrint('[CustomerBrowse] chef_orderable_for_customers_batch failed: $e\n$st');
      return {for (final id in uniq) id: false};
    }
  }

  // ─── Available dishes (realtime stream) ──────────────────────────────

  /// Stream all available dishes with remaining > 0.
  Stream<List<DishEntity>> watchAvailableDishes() {
    return _sb
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      // Filter by availability and remaining quantity.
      final available = rows.where((r) {
        final isAvailable = r['is_available'] as bool? ?? false;
        final moderationStatus = r['moderation_status']?.toString();
        final remainingRaw = r['remaining_quantity'];
        final remaining =
            remainingRaw is num ? remainingRaw.toInt() : int.tryParse(remainingRaw?.toString() ?? '') ?? 0;
        return menuItemRowVisibleInCustomerBrowse(
          isAvailable: isAvailable,
          moderationStatus: moderationStatus,
          remainingQuantity: remaining,
        );
      }).toList();
      if (available.isEmpty) return <DishEntity>[];

      // Filter out dishes whose cook fails storefront rule (vacation / hours / open toggle).
      final chefIds = available
          .map((r) => r['chef_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (chefIds.isEmpty) {
        return available
            .map((r) => _tryDishFromRow(Map<String, dynamic>.from(r as Map)))
            .whereType<DishEntity>()
            .toList();
      }

      final chefs = await _sb
          .from('chef_profiles')
          .select(
            'id, is_online, vacation_mode, vacation_start, vacation_end, '
            'working_hours_start, working_hours_end, working_hours, '
            'suspended, approval_status, initial_approval_at, access_level, documents_operational_ok, '
            'freeze_until',
          )
          .inFilter('id', chefIds);

      final allowed = <String, bool>{};
      for (final raw in chefs as List) {
        final c = Map<String, dynamic>.from(raw as Map);
        final id = c['id'] as String?;
        if (id == null) continue;
        final doc = ChefDocModel.fromSupabase(c);
        allowed[id] = doc.hasKitchenMapPin &&
            doc.storefrontEvaluation.isAcceptingOrders &&
            storefrontAccountAllowsListings(c);
      }

      final filtered = available.where((r) {
        final cid = r['chef_id'] as String?;
        if (cid == null) return false;
        return allowed[cid] ?? false;
      }).toList();

      return filtered
          .map((r) => _tryDishFromRow(Map<String, dynamic>.from(r as Map)))
          .whereType<DishEntity>()
          .toList();
    });
  }

  /// Stream a single chef's dishes (same visibility rules as [watchAvailableDishes]: not suspended, approved account).
  Stream<List<DishEntity>> watchChefDishes(String chefId) {
    if (chefId.isEmpty) return Stream.value(const <DishEntity>[]);
    return _sb
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('chef_id', chefId)
        .asyncMap((rows) async {
      final profile = await _sb
          .from('chef_profiles')
          .select(
            'suspended, approval_status, initial_approval_at, access_level, documents_operational_ok, is_online, vacation_mode, vacation_start, vacation_end, '
            'working_hours_start, working_hours_end, working_hours, '
            'freeze_until',
          )
          .eq('id', chefId)
          .maybeSingle();
      if (profile == null) return <DishEntity>[];
      if (!storefrontAccountAllowsListings(Map<String, dynamic>.from(profile as Map))) {
        return <DishEntity>[];
      }
      final doc = ChefDocModel.fromSupabase(profile);
      if (!doc.hasKitchenMapPin) return <DishEntity>[];
      if (!doc.storefrontEvaluation.isAcceptingOrders) return <DishEntity>[];

      final serverOk = await fetchChefOrderableBatch({chefId});
      if (serverOk[chefId] != true) return <DishEntity>[];

      return rows
          .where((r) {
            final moderationStatus = r['moderation_status']?.toString();
            final remainingRaw = r['remaining_quantity'];
            final remaining =
                remainingRaw is num ? remainingRaw.toInt() : int.tryParse(remainingRaw?.toString() ?? '') ?? 0;
            return menuItemRowVisibleInCustomerBrowse(
              isAvailable: r['is_available'] == true,
              moderationStatus: moderationStatus,
              remainingQuantity: remaining,
            );
          })
          .map((r) => _tryDishFromRow(Map<String, dynamic>.from(r as Map)))
          .whereType<DishEntity>()
          .toList();
    });
  }

  // ─── Chefs (for customer browse) ─────────────────────────────────────

  Stream<List<ChefDocModel>> watchAllChefs() {
    return _sb
        .from('chef_profiles')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      final candidates = rows.where((r) {
        final m = Map<String, dynamic>.from(r as Map);
        if (!storefrontAccountAllowsListings(m)) return false;
        final doc = ChefDocModel.fromSupabase(m);
        return doc.hasKitchenMapPin && doc.storefrontEvaluation.isAcceptingOrders;
      }).toList();
      if (candidates.isEmpty) return <ChefDocModel>[];
      final ids = candidates
          .map((r) => Map<String, dynamic>.from(r as Map)['id'] as String?)
          .whereType<String>()
          .toSet();
      final serverOk = await fetchChefOrderableBatch(ids);
      return candidates
          .where((r) {
            final id = Map<String, dynamic>.from(r as Map)['id'] as String?;
            return id != null && (serverOk[id] ?? false);
          })
          .map(_chefFromRow)
          .toList();
    });
  }

  Future<ChefDocModel?> fetchChef(String chefId) async {
    final row = await _sb
        .from('chef_profiles')
        .select(
          'id, kitchen_name, is_online, vacation_mode, vacation_start, vacation_end, '
          'suspended, approval_status, initial_approval_at, access_level, documents_operational_ok, working_hours_start, working_hours_end, working_hours, '
            'bio, kitchen_city, kitchen_latitude, kitchen_longitude, '
            'freeze_until',
        )
        .eq('id', chefId)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row as Map);
    if (!storefrontAccountAllowsListings(m)) return null;
    final doc = ChefDocModel.fromSupabase(m);
    if (!doc.hasKitchenMapPin || !doc.storefrontEvaluation.isAcceptingOrders) return null;
    final serverOk = await fetchChefOrderableBatch({chefId});
    if (serverOk[chefId] != true) return null;
    return _chefFromRow(m);
  }

  /// Client-side checks before [CustomerOrdersSupabaseDatasource.createOrder].
  /// Mirrors browse/storefront rules; Supabase RLS remains the final gate.
  Future<String?> validateCheckoutCart(List<CartItemModel> items) async {
    if (items.isEmpty) {
      return 'Your cart is empty. Add dishes before placing an order.';
    }
    for (final item in items) {
      if (item.chefId.trim().isEmpty || item.dishId.trim().isEmpty) {
        return 'Your cart has an invalid item. Open the cart and remove it, then add the dish again.';
      }
      if (item.quantity < 1) {
        return 'Adjust quantities in your cart before checkout.';
      }
    }

    final dishIds = items.map((e) => e.dishId).toSet().toList();
    final Map<String, Map<String, dynamic>> dishRows = {};
    const chunk = 60;
    for (var i = 0; i < dishIds.length; i += chunk) {
      final slice = dishIds.sublist(i, i + chunk > dishIds.length ? dishIds.length : i + chunk);
      final res = await _sb
          .from('menu_items')
          .select('id, chef_id, remaining_quantity, is_available, moderation_status, name')
          .inFilter('id', slice);
      for (final raw in res as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id']?.toString();
        if (id != null && id.isNotEmpty) dishRows[id] = m;
      }
    }

    for (final item in items) {
      final row = dishRows[item.dishId];
      if (row == null) {
        return '"${item.dishName}" is no longer available. Update your cart and try again.';
      }
      final rowChef = row['chef_id']?.toString() ?? '';
      if (rowChef != item.chefId) {
        return 'Cart needs a refresh: a dish no longer matches its kitchen. Update your cart.';
      }
      if (row['is_available'] != true) {
        return '"${item.dishName}" is unavailable right now. Remove it or lower the quantity in your cart.';
      }
      final mod = row['moderation_status']?.toString();
      if (mod != null && mod.isNotEmpty && mod != 'approved') {
        return '"${item.dishName}" is not available for order. Update your cart.';
      }
      final remaining = (row['remaining_quantity'] as num?)?.toInt() ?? 0;
      if (item.quantity > remaining) {
        final label = remaining <= 0 ? 'sold out' : 'only $remaining left';
        return '"${item.dishName}" is $label. Update quantities in your cart.';
      }
    }

    final chefIds = items.map((e) => e.chefId).toSet();
    for (final chefId in chefIds) {
      final label =
          items.firstWhere((e) => e.chefId == chefId, orElse: () => items.first).chefName.trim();
      final display = label.isNotEmpty ? label : 'This kitchen';

      final profile = await _sb
          .from('chef_profiles')
          .select(
            'id, is_online, vacation_mode, vacation_start, vacation_end, '
            'working_hours_start, working_hours_end, working_hours, '
            'suspended, approval_status, initial_approval_at, access_level, documents_operational_ok, '
            'freeze_until',
          )
          .eq('id', chefId)
          .maybeSingle();

      if (profile == null) {
        return '$display is not accepting orders right now. Remove their dishes or try again later.';
      }

      final profileMap = Map<String, dynamic>.from(profile as Map);
      if (!storefrontAccountAllowsListings(profileMap)) {
        return '$display is temporarily unavailable. Remove their dishes from your cart.';
      }

      final doc = ChefDocModel.fromSupabase(profileMap);
      if (!doc.storefrontEvaluation.isAcceptingOrders) {
        final r = doc.storefrontEvaluation.reason;
        if (r == ChefStorefrontReason.frozen) {
          return 'Temporarily unavailable — $display cannot take new orders right now.';
        }
        if (r == ChefStorefrontReason.vacation) {
          return '$display is on vacation and is not taking orders.';
        }
        if (r == ChefStorefrontReason.outsideWorkingHours) {
          final hint = doc.storefrontEvaluation.opensAtLabel;
          if (hint != null && hint.isNotEmpty) {
            return '$display is outside working hours (opens around $hint). Try again later.';
          }
          return '$display is outside working hours. Try again later.';
        }
        if (r == ChefStorefrontReason.offline) {
          return '$display is offline right now. Try again when the kitchen is open.';
        }
        return '$display is not taking orders right now. Try again later.';
      }
    }

    final orderable = await fetchChefOrderableBatch(items.map((e) => e.chefId).toSet());
    for (final chefId in chefIds) {
      if (orderable[chefId] == true) continue;
      final label =
          items.firstWhere((e) => e.chefId == chefId, orElse: () => items.first).chefName.trim();
      final display = label.isNotEmpty ? label : 'This kitchen';
      return '$display cannot take orders right now. Remove their dishes from your cart and try again.';
    }

    return null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  /// Skips rows with missing id (prevents cast crashes on bad data).
  static DishEntity? _tryDishFromRow(Map<String, dynamic> r) {
    // category is a single text column in existing schema
    final cat = r['category'] as String? ?? '';
    final categories = cat.isNotEmpty ? [cat] : <String>[];

    final remainingRaw = r['remaining_quantity'];
    final remainingQuantity =
        remainingRaw is num ? remainingRaw.toInt() : int.tryParse(remainingRaw?.toString() ?? '') ?? 0;
    final dailyQty = (r['daily_quantity'] as num?)?.toInt() ?? 0;

    final id = (r['id'] ?? '').toString();
    if (id.isEmpty) return null;

    return DishEntity(
      id: id,
      name: r['name'] as String? ?? '',
      description: r['description'] as String? ?? '',
      price: _toDouble(r['price']),
      imageUrl: r['image_url'] as String?,
      categories: categories,
      isAvailable: r['is_available'] as bool? ?? true,
      preparationTime: dailyQty,
      remainingQuantity: remainingQuantity,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
          DateTime.now(),
      chefId: r['chef_id'] as String?,
    );
  }

  static ChefDocModel _chefFromRow(Map<String, dynamic> r) {
    return ChefDocModel.fromSupabase(r);
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}