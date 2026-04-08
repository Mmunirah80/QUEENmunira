import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chef profile / location / availability writes must stay scoped to the authenticated chef row.
void main() {
  test('ChefFirebaseDataSource profile and location updates use .eq(id, chefId)', () {
    final f = File('lib/features/cook/data/datasources/chef_firebase_datasource.dart');
    expect(f.existsSync(), isTrue);
    final s = f.readAsStringSync();
    expect(s.contains(".eq('id', chefId)"), isTrue);
    expect(s.contains("if (chefId.isEmpty) return"), isTrue);
    expect(s.contains("'kitchen_latitude'"), isTrue);
    expect(s.contains("'kitchen_longitude'"), isTrue);
    expect(s.contains("'vacation_mode'"), isTrue);
    expect(s.contains("'is_online'"), isTrue);
  });
}
