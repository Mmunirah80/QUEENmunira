import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/data/datasources/customer_browse_supabase_datasource.dart';

/// Customer discovery gate: [storefrontAccountAllowsListings] + profile flags.
void main() {
  group('storefrontAccountAllowsListings — verification / access', () {
    test('full_access + documents_operational_ok + not suspended => visible', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'full_access',
          'documents_operational_ok': true,
          'approval_status': 'approved',
        }),
        isTrue,
      );
    });

    test('full_access but documents_operational_ok false => not visible (strict path)', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'full_access',
          'documents_operational_ok': false,
          'approval_status': 'approved',
        }),
        isFalse,
      );
    });

    test('partial_access does not use documents_operational_ok for listing gate', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'partial_access',
          'documents_operational_ok': false,
          'approval_status': 'approved',
        }),
        isTrue,
      );
    });

    test('blocked / non-full access without legacy approval => not visible', () {
      expect(
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
          'suspended': false,
          'access_level': 'blocked_access',
          'documents_operational_ok': false,
          'approval_status': 'pending',
        }),
        isFalse,
      );
    });
  });
}
