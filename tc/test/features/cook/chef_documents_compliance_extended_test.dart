import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/cook/data/chef_documents_compliance.dart';

import 'support/chef_document_review_simulator.dart';

void main() {
  Map<String, dynamic> row(
    String type, {
    required String status,
    String? expiry,
    bool noExpiry = false,
    String? rejectionReason,
  }) {
    return {
      'document_type': type,
      'status': status,
      if (expiry != null) 'expiry_date': expiry,
      'no_expiry': noExpiry,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
    };
  }

  group('Access level ↔ ChefDocumentsCompliance (operational gate)', () {
    test('both required approved + valid expiry => canReceiveOrders (full operational)', () {
      final now = DateTime.now();
      final future =
          '${now.year + 2}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', expiry: future),
        row('freelancer_id', status: 'approved', expiry: future),
      ]);
      expect(c.canReceiveOrders, isTrue);
    });

    test('one approved + one pending => NOT full operational', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
        row('freelancer_id', status: 'pending_review', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('one approved + one rejected => NOT full operational', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
        row('freelancer_id', status: 'rejected', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('both pending => NOT full operational', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'pending_review', noExpiry: true),
        row('freelancer_id', status: 'pending_review', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('missing required type rows => NOT full operational', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('empty document list => NOT full operational', () {
      expect(ChefDocumentsCompliance.evaluate([]).canReceiveOrders, isFalse);
    });
  });

  group('Expiry behaviour', () {
    test('approved with future expiry remains valid for operations', () {
      final now = DateTime.now();
      final future =
          '${now.year + 1}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', expiry: future),
        row('freelancer_id', status: 'approved', expiry: future),
      ]);
      expect(c.canReceiveOrders, isTrue);
    });

    test('approved with calendar-expired date fails operations (not no_expiry)', () {
      final past = DateTime.now().subtract(const Duration(days: 10));
      final s =
          '${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}';
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', expiry: s),
        row('freelancer_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('status expired on row fails even if date string is future', () {
      final now = DateTime.now();
      final future =
          '${now.year + 1}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'expired', expiry: future),
        row('freelancer_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });

    test('expiringWithinDays warns on approved doc inside window', () {
      final now = DateTime.now();
      final soon = now.add(const Duration(days: 3));
      final s =
          '${soon.year}-${soon.month.toString().padLeft(2, '0')}-${soon.day.toString().padLeft(2, '0')}';
      final c = ChefDocumentsCompliance.evaluate(
        [
          row('id_document', status: 'approved', expiry: s),
          row('health_or_kitchen_document', status: 'approved', noExpiry: true),
        ],
        warnWithinDays: 7,
      );
      expect(c.expiringWithinDays.containsKey('id_document'), isTrue);
    });

    test('current behaviour: malformed expiry string on approved doc without no_expiry — operations still pass', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', expiry: 'not-a-date'),
        row('freelancer_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isTrue);
    });
  });

  group('Document submission (simulated)', () {
    test('chef can submit first then second required document as pending_review', () {
      final sim = ChefDocumentReviewSimulator({});
      sim.submitPending('national_id', noExpiry: true);
      expect(sim.row('national_id')!['status'], 'pending_review');
      sim.submitPending('freelancer_id', noExpiry: true);
      expect(sim.row('freelancer_id')!['status'], 'pending_review');
      expect(sim.compliance().canReceiveOrders, isFalse);
    });
  });

  group('Duplicate handling', () {
    test('last row per document_type wins in evaluate list order', () {
      final c = ChefDocumentsCompliance.evaluate([
        row('national_id', status: 'approved', noExpiry: true),
        row('national_id', status: 'rejected'),
        row('freelancer_id', status: 'approved', noExpiry: true),
      ]);
      expect(c.canReceiveOrders, isFalse);
    });
  });
}
