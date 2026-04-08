import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/menu/naham_menu_categories.dart';

void main() {
  group('normalizeDishCategory', () {
    test('empty → Other', () {
      expect(NahamMenuCategories.normalizeDishCategory(null), 'Other');
      expect(NahamMenuCategories.normalizeDishCategory(''), 'Other');
      expect(NahamMenuCategories.normalizeDishCategory('   '), 'Other');
    });

    test('known region preserved (case-insensitive)', () {
      expect(NahamMenuCategories.normalizeDishCategory('najdi'), 'Najdi');
      expect(NahamMenuCategories.normalizeDishCategory('Northern'), 'Northern');
    });

    test('unknown legacy value maps to Other', () {
      expect(NahamMenuCategories.normalizeDishCategory('Western'), 'Other');
    });
  });

  group('dishMatchesFilter', () {
    test('All chip matches any category', () {
      expect(NahamMenuCategories.dishMatchesFilter(null, NahamMenuCategories.allChipLabel), isTrue);
      expect(NahamMenuCategories.dishMatchesFilter('Najdi', NahamMenuCategories.allChipLabel), isTrue);
    });

    test('Other chip includes empty and non-canonical categories', () {
      expect(NahamMenuCategories.dishMatchesFilter('', 'Other'), isTrue);
      expect(NahamMenuCategories.dishMatchesFilter('Western', 'Other'), isTrue);
    });

    test('regional chip requires exact match', () {
      expect(NahamMenuCategories.dishMatchesFilter('Najdi', 'Najdi'), isTrue);
      expect(NahamMenuCategories.dishMatchesFilter('Northern', 'Najdi'), isFalse);
    });
  });
}
