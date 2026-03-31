import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../domain/entities/dish_entity.dart';
import '../models/dish_model.dart';
import 'menu_remote_datasource.dart';

/// Supabase implementation of [MenuRemoteDataSource] for a single chef.
/// Table: menu_items (id, chef_id, name, description, price, image_url,
/// category, daily_quantity, remaining_quantity, is_available, created_at).
class MenuSupabaseDataSource implements MenuRemoteDataSource {
  MenuSupabaseDataSource({required this.chefId});

  final String chefId;
  SupabaseClient get _sb => SupabaseConfig.client;

  static DishModel _dishFromRow(Map<String, dynamic> r) {
    final cat = r['category'] as String? ?? '';
    final categories = cat.isNotEmpty ? [cat] : <String>[];
    final daily = (r['daily_quantity'] as num?)?.toInt() ?? 0;
    final remRaw = r['remaining_quantity'];
    final remaining = remRaw is num ? remRaw.toInt() : daily;
    return DishModel(
      id: r['id'] as String,
      name: r['name'] as String? ?? '',
      description: r['description'] as String? ?? '',
      price: _toDouble(r['price']),
      imageUrl: r['image_url'] as String?,
      categories: categories,
      isAvailable: r['is_available'] as bool? ?? true,
      // [preparationTime] on this entity carries today's planned portions (daily_quantity).
      preparationTime: daily,
      remainingQuantity: remaining < 0 ? 0 : remaining,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      chefId: r['chef_id'] as String?,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// Stream all dishes for this chef (for menu list and home capacity).
  Stream<List<DishEntity>> watchChefDishes() {
    return _sb
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('chef_id', chefId)
        .map((rows) => rows.map(_dishFromRow).toList());
  }

  @override
  Future<List<DishModel>> getDishes() async {
    final res = await _sb.from('menu_items').select().eq('chef_id', chefId);
    final list = res as List<dynamic>? ?? [];
    return list.map((r) => _dishFromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  @override
  Future<DishModel> getDishById(String id) async {
    final res = await _sb.from('menu_items').select().eq('id', id).eq('chef_id', chefId).maybeSingle();
    if (res == null) throw Exception('Dish not found');
    return _dishFromRow(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<DishModel> createDish(DishModel dish) async {
    final uuid = dish.id.isEmpty ? const Uuid().v4() : dish.id;
    final category = dish.categories.isNotEmpty ? dish.categories.first : 'Other';
    await _sb.from('menu_items').insert({
      'id': uuid,
      'chef_id': chefId,
      'name': dish.name,
      'description': dish.description,
      'price': dish.price,
      'image_url': dish.imageUrl,
      'category': category,
      'daily_quantity': dish.preparationTime,
      'remaining_quantity': 99,
      'is_available': dish.isAvailable,
      'created_at': dish.createdAt.toUtc().toIso8601String(),
    });
    return getDishById(uuid);
  }

  @override
  Future<DishModel> updateDish(DishModel dish) async {
    final category = dish.categories.isNotEmpty ? dish.categories.first : 'Other';
    await _sb.from('menu_items').update({
      'name': dish.name,
      'description': dish.description,
      'price': dish.price,
      'image_url': dish.imageUrl,
      'category': category,
      'daily_quantity': dish.preparationTime,
      'is_available': dish.isAvailable,
    }).eq('id', dish.id).eq('chef_id', chefId);
    return getDishById(dish.id);
  }

  @override
  Future<void> deleteDish(String id) async {
    await _sb.from('menu_items').delete().eq('id', id).eq('chef_id', chefId);
  }

  @override
  Future<void> toggleDishAvailability(String id) async {
    final row = await _sb.from('menu_items').select('is_available').eq('id', id).eq('chef_id', chefId).maybeSingle();
    if (row == null) return;
    final current = row['is_available'] as bool? ?? true;
    await _sb.from('menu_items').update({'is_available': !current}).eq('id', id).eq('chef_id', chefId);
  }

}
