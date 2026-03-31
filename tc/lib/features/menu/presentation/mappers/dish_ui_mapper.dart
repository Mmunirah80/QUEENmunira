import 'package:flutter/material.dart';

import '../../domain/entities/dish_entity.dart';

/// Maps [DishEntity] to the UI map shape used by the cook menu screen.
/// When backend is connected, entities come from API; only this mapping may need tweaks.
class DishUiMapper {
  DishUiMapper._();

  static const _categoryEmoji = {
    'Rice': '🍛',
    'Grills': '🥘',
    'Sweets': '🍮',
    'Pastries': '🥐',
    'Salads': '🥗',
    'Main Course': '🍽️',
    'Chicken': '🍗',
    'Vegetarian': '🥬',
    'Appetizer': '🥗',
    'Dessert': '🍮',
  };

  static const _categoryColor = {
    'Rice': Color(0xFFFFF3E0),
    'Grills': Color(0xFFF0EBFF),
    'Sweets': Color(0xFFFFF8E1),
    'Pastries': Color(0xFFFCE4EC),
    'Salads': Color(0xFFE8F5E9),
    'Main Course': Color(0xFFE3F2FD),
    'Chicken': Color(0xFFFFF3E0),
    'Vegetarian': Color(0xFFE8F5E9),
    'Appetizer': Color(0xFFF3E5F5),
    'Dessert': Color(0xFFFFF8E1),
  };

  static String _category(DishEntity e) {
    if (e.categories.isEmpty) return 'Other';
    final first = e.categories.first;
    return first;
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
