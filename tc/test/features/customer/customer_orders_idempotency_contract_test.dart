import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F.32 — duplicate submit protection via idempotency key (source contract).
void main() {
  test('CustomerOrdersSupabaseDatasource createOrder persists idempotency_key', () {
    final f = File('lib/features/customer/data/datasources/customer_orders_supabase_datasource.dart');
    expect(f.existsSync(), isTrue);
    final s = f.readAsStringSync();
    expect(s.contains('idempotency_key'), isTrue);
    expect(s.contains('idempotencyKey'), isTrue);
    expect(s.contains('Reusing existing order'), isTrue);
  });
}
