import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// E.20: Admin reels list must not be region-scoped (static source check).
void main() {
  test('fetchAllReelsForAdmin implementation does not apply region_id / locality filters', () {
    final path = File('lib/features/admin/data/datasources/admin_supabase_datasource.dart');
    expect(path.existsSync(), isTrue, reason: 'Admin datasource file must exist');
    final s = path.readAsStringSync();
    final idx = s.indexOf('fetchAllReelsForAdmin');
    expect(idx, greaterThan(-1));
    final end = idx + 1200 > s.length ? s.length : idx + 1200;
    final window = s.substring(idx, end);
    expect(window.contains('region_id'), isFalse);
    expect(window.contains('localityCity'), isFalse);
    expect(window.contains('kitchen_city'), isFalse);
    expect(window.contains(".from('reels')"), isTrue);
  });
}
