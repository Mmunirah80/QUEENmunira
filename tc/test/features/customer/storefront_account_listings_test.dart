import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/data/datasources/customer_browse_supabase_datasource.dart';

void main() {
  group('storefrontAccountAllowsListings', () {
    test('suspended chef cannot list', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': true,
          'access_level': 'full_access',
          'documents_operational_ok': true,
        }),
        isFalse,
      );
    });

    test('full_access requires documents_operational_ok', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'full_access',
          'documents_operational_ok': false,
        }),
        isFalse,
      );
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'full_access',
          'documents_operational_ok': true,
        }),
        isTrue,
      );
    });

    test('approved approval_status allows listings', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'partial_access',
          'approval_status': 'approved',
        }),
        isTrue,
      );
    });

    test('established kitchen with waiting approval can list (renewal path)', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'partial_access',
          'approval_status': 'waiting',
          'initial_approval_at': '2025-01-01',
        }),
        isTrue,
      );
    });
  });
}
