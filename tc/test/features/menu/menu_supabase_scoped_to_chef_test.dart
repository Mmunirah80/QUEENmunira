import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cook menu mutations must stay scoped to [chef_id] (no cross-kitchen edits).
void main() {
  test('MenuSupabaseDataSource update/delete/toggle filter by chef_id', () {
    final f = File('lib/features/menu/data/datasources/menu_supabase_datasource.dart');
    expect(f.existsSync(), isTrue);
    final s = f.readAsStringSync();
    expect(s.contains(".eq('chef_id', chefId)"), isTrue);
    expect(s.contains("await _sb.from('menu_items').insert"), isTrue);
    expect(s.contains("'chef_id': chefId"), isTrue);
  });
}
