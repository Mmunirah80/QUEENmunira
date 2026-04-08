import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/cook/data/chef_documents_compliance.dart';

/// Document rows drive operations gating (national_id + freelancer_id required).
void main() {
  Map<String, dynamic> row(
    String type, {
    required String status,
    String? expiry,
    bool noExpiry = false,
  }) {
    return {
      'document_type': type,
      'status': status,
      if (expiry != null) 'expiry_date': expiry,
      'no_expiry': noExpiry,
    };
  }

  group('ChefDocumentsCompliance.evaluate', () {
    test('both required types approved + not expired → canReceiveOrders', () {
      final now = DateTime.now();
      final future =
          '${now.year + 1}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', expiry: future),
        row('freelancer_id', status: 'approved', expiry: future),
      ]);
      expect(c.canReceiveOrders, isTrue);
    });

    test('only national_id approved → cannot receive orders', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('pending_review on one required type → cannot receive orders', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
        row('freelancer_id', status: 'pending_review'),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('rejected on one required type → cannot receive orders', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
        row('freelancer_id', status: 'rejected'),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('expired status on required type → cannot receive orders', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'expired'),
        row('freelancer_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('duplicate rows per type: last map entry wins (document ordering risk)', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
        row('national_id', status: 'rejected'),
        row('freelancer_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });
  });

  group('isDocumentExpired', () {
    test('past calendar date → expired', () {
      final past = DateTime.now().subtract(const Duration(days: 400));
      final s =
          '${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}';
      expect(ChefDocumentsCompliance.isDocumentExpired(s), isTrue);
    });
  });
}
