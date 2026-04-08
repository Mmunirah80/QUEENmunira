import 'package:flutter/material.dart';

import '../../../../core/menu/naham_menu_categories.dart';
import '../../domain/entities/dish_entity.dart';

/// Maps [DishEntity] to the UI map shape used by the cook menu screen.
/// Category labels match [NahamMenuCategories.dishCategoryIds] (same as customer browse).
class DishUiMapper {
  DishUiMapper._();

  static const _categoryEmoji = {
    'Najdi': '🍛',
    'Northern': '🥘',
    'Eastern': '🍲',
    'Southern': '🍲',
    'Sweets': '🍰',
    'Other': '🍽️',
  };

  static const _categoryColor = {
    'Najdi': Color(0xFFFFF3E0),
    'Northern': Color(0xFFF0EBFF),
    'Eastern': Color(0xFFE8F5E9),
    'Southern': Color(0xFFE3F2FD),
    'Sweets': Color(0xFFFFF8E1),
    'Other': Color(0xFFF5F5F5),
  };

  static String _category(DishEntity e) {
    final raw = e.categories.isEmpty ? '' : e.categories.first;
    return NahamMenuCategories.normalizeDishCategory(raw);
  }

  static Map<String, dynamic> toMenuMap(DishEntity e) {
    final cat = _category(e);
    return {
      'id': e.id,
      'name': e.name,
      'description': e.description,
      'price': e.price,
      'prepTime': '${e.preparationTime} min',
      'category': cat,
      'emoji': _categoryEmoji[cat] ?? '🍽️',
      'color': _categoryColor[cat] ?? const Color(0xFFF5F5F5),
      'available': e.isAvailable,
      'badge': '',
    };
  }

  static List<Map<String, dynamic>> toMenuMaps(List<DishEntity> list) {
    return list.map(toMenuMap).toList();
  }
}
