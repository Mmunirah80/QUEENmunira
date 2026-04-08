import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/customer/data/datasources/customer_browse_supabase_datasource.dart';

/// Regression: storefront listing gate must stay aligned with access_level + operational flag.
void main() {
  group('CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings', () {
    test('full_access without documents_operational_ok → false', () {
      final ok = CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
        'suspended': false,
        'access_level': 'full_access',
        'documents_operational_ok': false,
        'approval_status': 'approved',
      });
      expect(ok, isFalse);
    });

    test('full_access with documents_operational_ok → true', () {
      final ok = CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
        'suspended': false,
        'access_level': 'full_access',
        'documents_operational_ok': true,
        'approval_status': 'approved',
      });
      expect(ok, isTrue);
    });

    test('suspended → false regardless of access', () {
      final ok = CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
        'suspended': true,
        'access_level': 'full_access',
        'documents_operational_ok': true,
        'approval_status': 'approved',
      });
      expect(ok, isFalse);
    });

    test('legacy approval path when access_level not full_access (migration edge)', () {
      final ok = CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
        'suspended': false,
        'access_level': 'partial_access',
        'documents_operational_ok': false,
        'approval_status': 'approved',
      });
      expect(ok, isTrue);
    });
  });
}
