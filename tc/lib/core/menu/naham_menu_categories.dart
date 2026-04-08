import 'package:flutter/material.dart';

/// Single source of truth for dish categories: `menu_items.category` and customer browse chips.
///
/// Order of [dishCategoryIds] matches customer home chips (after [allChipLabel]).
abstract final class NahamMenuCategories {
  NahamMenuCategories._();

  static const String allChipLabel = 'All';

  /// Values persisted in Supabase `menu_items.category`.
  static const List<String> dishCategoryIds = [
    'Najdi',
    'Northern',
    'Eastern',
    'Southern',
    'Sweets',
    'Other',
  ];

  /// Customer filter tabs + cook menu tabs (first entry is "All").
  static List<String> get filterChipsWithAll => [allChipLabel, ...dishCategoryIds];

  /// Regional chips use these assets (customer home + cook menu optional).
  static const Map<String, String> chipImageAssetById = {
    'Najdi': 'assets/images/nj.png',
    'Northern': 'assets/images/nt.png',
    'Eastern': 'assets/images/es.png',
    'Southern': 'assets/images/so.png',
  };

  static IconData iconForChip(String chip) {
    return switch (chip) {
      allChipLabel => Icons.restaurant_menu,
      'Najdi' => Icons.rice_bowl,
      'Northern' => Icons.kebab_dining,
      'Eastern' => Icons.set_meal,
      'Southern' => Icons.soup_kitchen,
      'Sweets' => Icons.cake,
      'Other' => Icons.fastfood,
      _ => Icons.restaurant_menu,
    };
  }

  /// Whether a dish appears under [activeChip] (e.g. legacy `Western` → [Other]).
  static bool dishMatchesFilter(String? dishCategory, String activeChip) {
    if (activeChip == allChipLabel) return true;
    final c = dishCategory?.trim() ?? '';
    if (activeChip == 'Other') {
      if (c.isEmpty) return true;
      return !dishCategoryIds.contains(c);
    }
    return c.toLowerCase() == activeChip.toLowerCase();
  }

  /// Pick list for add/edit dish; maps unknown DB values (e.g. `Western`) to `Other`.
  static String normalizeDishCategory(String? raw) {
    final c = raw?.trim() ?? '';
    if (c.isEmpty) return 'Other';
    for (final id in dishCategoryIds) {
      if (id.toLowerCase() == c.toLowerCase()) return id;
    }
    return 'Other';
  }
}
