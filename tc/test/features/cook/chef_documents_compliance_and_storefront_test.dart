import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/cook/data/chef_documents_compliance.dart';
import 'package:naham_cook_app/features/customer/data/datasources/customer_browse_supabase_datasource.dart';

/// Links cook-side compliance with customer storefront profile gate (server sets flags; we assert pairs).
void main() {
  Map<String, dynamic> doc(String type, {required String status, bool noExpiry = true}) {
    return {
      'document_type': type,
      'status': status,
      'no_expiry': noExpiry,
    };
  }

  bool storefront({
    required String accessLevel,
    required bool documentsOperationalOk,
    bool suspended = false,
    String approvalStatus = 'approved',
  }) {
    return CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
      'suspended': suspended,
      'access_level': accessLevel,
      'documents_operational_ok': documentsOperationalOk,
      'approval_status': approvalStatus,
    });
  }

  group('Compliance + storefront scenarios', () {
    test('when both docs operationally approved in compliance, typical server pair is full_access + documents_operational_ok', () {
      final compliance = ChefDocumentsCompliance.evaluate([
        doc('national_id', status: 'approved'),
        doc('freelancer_id', status: 'approved'),
      ]);
      expect(compliance.canReceiveOrders, isTrue);

      final visible = storefront(
        accessLevel: 'full_access',
        documentsOperationalOk: true,
      );
      expect(visible, isTrue);
    });

    test('compliance fails => cook should not be treated as operationally cleared even if profile lags', () {
      final compliance = ChefDocumentsCompliance.evaluate([
        doc('national_id', status: 'approved'),
        doc('freelancer_id', status: 'rejected'),
      ]);
      expect(compliance.canReceiveOrders, isFalse);

      final strictStorefront = storefront(
        accessLevel: 'full_access',
        documentsOperationalOk: false,
      );
      expect(strictStorefront, isFalse);
    });

    test('suspended chef never appears regardless of compliance snapshot', () {
      final compliance = ChefDocumentsCompliance.evaluate([
        doc('national_id', status: 'approved'),
        doc('freelancer_id', status: 'approved'),
      ]);
      expect(compliance.canReceiveOrders, isTrue);

      final blocked = CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings({
        'suspended': true,
        'access_level': 'full_access',
        'documents_operational_ok': true,
        'approval_status': 'approved',
      });
      expect(blocked, isFalse);
    });
  });
}
