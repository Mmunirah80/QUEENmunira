import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chef [streamMyReels] must scope to [chef_id] only (no global leak).
void main() {
  test('streamMyReels selects reels table filtered by chef_id', () {
    final path = File('lib/features/reels/data/datasources/reels_firebase_datasource.dart');
    expect(path.existsSync(), isTrue);
    final s = path.readAsStringSync();
    final idx = s.indexOf('streamMyReels');
    expect(idx, greaterThan(-1));
    final end = idx + 800 > s.length ? s.length : idx + 800;
    final window = s.substring(idx, end);
    expect(window.contains(".from('reels')"), isTrue);
    expect(window.contains(".eq('chef_id'"), isTrue);
  });
}
