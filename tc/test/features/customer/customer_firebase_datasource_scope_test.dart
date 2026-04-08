import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Favorites, addresses, and profile writes must be scoped to `customer_id` / uid.
void main() {
  test('CustomerFirebaseDataSource favorites, addresses, notifications use customer_id', () {
    final f = File('lib/features/customer/data/datasources/customer_firebase_datasource.dart');
    expect(f.existsSync(), isTrue);
    final s = f.readAsStringSync();
    expect(s.contains(".eq('customer_id', uid)"), isTrue);
    expect(s.contains("from('favorites')"), isTrue);
    expect(s.contains("from('addresses')"), isTrue);
    expect(s.contains("from('notifications')"), isTrue);
    expect(s.contains('watchNotifications'), isTrue);
  });
}
