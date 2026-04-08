import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/data/datasources/customer_browse_supabase_datasource.dart';

void main() {
  group('storefrontAccountAllowsListings', () {
    test('pending with initial_approval_at is not orderable (matches DB insert gate)', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'partial_access',
          'approval_status': 'pending',
          'initial_approval_at': '2025-01-01T00:00:00Z',
          'documents_operational_ok': false,
        }),
        isFalse,
      );
    });

    test('approved is orderable at account level', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'partial_access',
          'approval_status': 'approved',
          'documents_operational_ok': false,
        }),
        isTrue,
      );
    });

    test('full_access requires documents_operational_ok', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'full_access',
          'approval_status': 'approved',
          'documents_operational_ok': false,
        }),
        isFalse,
      );
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'full_access',
          'approval_status': 'approved',
          'documents_operational_ok': true,
        }),
        isTrue,
      );
    });

    test('suspended is never orderable', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': true,
          'access_level': 'full_access',
          'approval_status': 'approved',
          'documents_operational_ok': true,
        }),
        isFalse,
      );
    });
  });
}
