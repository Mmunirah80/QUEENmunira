import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../../menu/domain/entities/dish_entity.dart';
import '../../../cook/data/models/chef_doc_model.dart';

/// Supabase datasource for dishes + chefs that customers browse.
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
        final isModeratedIn = moderationStatus == null || moderationStatus == 'approved';
        return isAvailable && remaining > 0 && isModeratedIn;
      }).toList();
      if (available.isEmpty) return <DishEntity>[];

      // Filter out dishes whose cook fails storefront rule (vacation / hours / open toggle).
      final chefIds = available
          .map((r) => r['chef_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (chefIds.isEmpty) {
        return available.map(_dishFromRow).toList();
      }

      final chefs = await _sb
          .from('chef_profiles')
          .select(
            'id, is_online, vacation_mode, vacation_start, vacation_end, '
            'working_hours_start, working_hours_end, working_hours, '
            'suspended, approval_status',
          )
          .inFilter('id', chefIds);

      final allowed = <String, bool>{};
      for (final raw in chefs as List) {
        final c = Map<String, dynamic>.from(raw as Map);
        final id = c['id'] as String?;
        if (id == null) continue;
        final suspended = c['suspended'] as bool? ?? false;
        final approval = c['approval_status']?.toString();
        final approved = approval == 'approved';
        final doc = ChefDocModel.fromSupabase(c);
        allowed[id] =
            doc.storefrontEvaluation.isAcceptingOrders && !suspended && approved;
      }

      final filtered = available.where((r) {
        final cid = r['chef_id'] as String?;
        if (cid == null) return false;
        return allowed[cid] ?? false;
      }).toList();

      return filtered.map(_dishFromRow).toList();
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
            'suspended, approval_status, is_online, vacation_mode, vacation_start, vacation_end, '
            'working_hours_start, working_hours_end, working_hours',
          )
          .eq('id', chefId)
          .maybeSingle();
      if (profile == null) return <DishEntity>[];
      final suspended = profile['suspended'] as bool? ?? false;
      final approval = profile['approval_status']?.toString();
      if (suspended || approval != 'approved') return <DishEntity>[];
      final doc = ChefDocModel.fromSupabase(profile);
      if (!doc.storefrontEvaluation.isAcceptingOrders) return <DishEntity>[];

      return rows
          .where((r) {
            final moderationStatus = r['moderation_status']?.toString();
            final isModeratedIn = moderationStatus == null || moderationStatus == 'approved';
            return r['is_available'] == true && isModeratedIn;
          })
          .map(_dishFromRow)
          .toList();
    });
  }

  // ─── Chefs (for customer browse) ─────────────────────────────────────

  Stream<List<ChefDocModel>> watchAllChefs() {
    return _sb
        .from('chef_profiles')
        .stream(primaryKey: ['id'])
        .map((rows) {
      return rows
          .where((r) {
            final suspended = r['suspended'] as bool? ?? false;
            final approval = r['approval_status']?.toString();
            final approved = approval == 'approved';
            if (suspended || !approved) return false;
            return ChefDocModel.fromSupabase(r).storefrontEvaluation.isAcceptingOrders;
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
          'suspended, approval_status, working_hours_start, working_hours_end, working_hours, '
          'bio, kitchen_city, kitchen_latitude, kitchen_longitude',
        )
        .eq('id', chefId)
        .maybeSingle();
    if (row == null) return null;
    final approval = row['approval_status']?.toString();
    if ((row['suspended'] as bool? ?? false) ||
        approval != 'approved') {
      return null;
    }
    return _chefFromRow(row);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  static DishEntity _dishFromRow(Map<String, dynamic> r) {
    // category is a single text column in existing schema
    final cat = r['category'] as String? ?? '';
    final categories = cat.isNotEmpty ? [cat] : <String>[];

    final remainingRaw = r['remaining_quantity'];
    final remainingQuantity =
        remainingRaw is num ? remainingRaw.toInt() : int.tryParse(remainingRaw?.toString() ?? '') ?? 0;

    return DishEntity(
      id: r['id'] as String,
      name: r['name'] as String? ?? '',
      description: r['description'] as String? ?? '',
      price: _toDouble(r['price']),
      imageUrl: r['image_url'] as String?,
      categories: categories,
      isAvailable: r['is_available'] as bool? ?? true,
      preparationTime: r['daily_quantity'] as int? ?? 30,
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