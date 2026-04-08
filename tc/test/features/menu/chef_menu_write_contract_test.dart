import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cook menu writes: chef ownership + non-negative capacity fields in insert/update.
void main() {
  test('MenuSupabaseDataSource create/update clamp negative daily/remaining to 0', () {
    final f = File('lib/features/menu/data/datasources/menu_supabase_datasource.dart');
    final s = f.readAsStringSync();
    expect(s.contains('dish.preparationTime < 0 ? 0'), isTrue);
    expect(s.contains('dish.remainingQuantity < 0 ? 0'), isTrue);
  });

  test('MenuSupabaseDataSource mutations always scope by chef_id', () {
    final f = File('lib/features/menu/data/datasources/menu_supabase_datasource.dart');
    final s = f.readAsStringSync();
    expect(s.split(".eq('chef_id', chefId)").length - 1, greaterThanOrEqualTo(3));
  });
}
