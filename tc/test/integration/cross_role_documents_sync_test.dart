import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/cook/data/chef_documents_compliance.dart';

import 'support/cross_role_sync_stores.dart';

/// B.8–11: same logical document rows observed by chef (compliance) and admin (queue).
void main() {
  const chefId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  Map<String, dynamic> docRow(String type, String status, {String? reason}) {
    return {
      'document_type': type,
      'status': status,
      'no_expiry': true,
      if (reason != null) 'rejection_reason': reason,
    };
  }

  group('DocumentSyncStore — cross-role consistency', () {
    test('chef upload pending → admin queue lists it; compliance blocks orders', () {
      final store = DocumentSyncStore()
        ..seedChef(chefId, [
          docRow('national_id', 'pending_review'),
          docRow('freelancer_id', 'pending_review'),
        ]);

      final pending = store.adminPendingQueue();
      expect(pending.length, 2);

      final chefView = ChefDocumentsCompliance.evaluate(store.chefRowsList(chefId));
      expect(chefView.canReceiveOrders, isFalse);
    });

    test('admin approves one doc → chef sees approved; other unchanged; ops still blocked', () {
      final store = DocumentSyncStore()
        ..seedChef(chefId, [
          docRow('national_id', 'pending_review'),
          docRow('freelancer_id', 'pending_review'),
        ]);

      store.adminSetDocument(chefId: chefId, documentType: 'national_id', status: 'approved');

      final rows = store.chefRowsList(chefId);
      final national = rows.firstWhere((r) => r['document_type'] == 'national_id');
      final free = rows.firstWhere((r) => r['document_type'] == 'freelancer_id');
      expect(national['status'], 'approved');
      expect(free['status'], 'pending_review');

      final chefView = ChefDocumentsCompliance.evaluate(rows);
      expect(chefView.canReceiveOrders, isFalse);
    });

    test('admin rejects one doc with reason → chef rows show rejection_reason', () {
      final store = DocumentSyncStore()
        ..seedChef(chefId, [
          docRow('national_id', 'approved'),
          docRow('freelancer_id', 'pending_review'),
        ]);

      store.adminSetDocument(
        chefId: chefId,
        documentType: 'freelancer_id',
        status: 'rejected',
        rejectionReason: 'Please upload a clearer scan.',
      );

      final free = store.chefRowsList(chefId).firstWhere((r) => r['document_type'] == 'freelancer_id');
      expect(free['status'], 'rejected');
      expect(free['rejection_reason'], 'Please upload a clearer scan.');
      expect(ChefDocumentsCompliance.evaluate(store.chefRowsList(chefId)).canReceiveOrders, isFalse);
    });

    test('both required approved → chef can receive orders', () {
      final store = DocumentSyncStore()
        ..seedChef(chefId, [
          docRow('national_id', 'approved'),
          docRow('freelancer_id', 'approved'),
        ]);

      expect(ChefDocumentsCompliance.evaluate(store.chefRowsList(chefId)).canReceiveOrders, isTrue);
      expect(store.adminPendingQueue(), isEmpty);
    });
  });
}
