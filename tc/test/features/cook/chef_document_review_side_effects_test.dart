import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/domain/admin_application_review_logic.dart';
import 'package:naham_cook_app/features/cook/data/chef_documents_compliance.dart';
import 'package:naham_cook_app/features/cook/data/cook_required_document_types.dart';

/// Same keys as SQL: `chef_document_id` for admin_document rows; activation once per chef.
bool _shouldInsertAdminDocumentNotification({
  required Set<String> existingKeys,
  required String documentId,
}) =>
    !existingKeys.contains(documentId);

bool _shouldInsertActivationNotification({
  required bool alreadyHasChefAccountActivated,
  required bool sendActivation,
}) {
  if (!sendActivation) return false;
  return !alreadyHasChefAccountActivated;
}

bool _shouldInsertActivationSystemMessage({required bool alreadyHasActivationMessage}) =>
    !alreadyHasActivationMessage;

/// Exercises domain rules aligned with cook shell gates and `apply_chef_document_review`
/// dedupe (see `supabase_apply_chef_document_review.sql`).
void main() {
  group('ChefDocumentsCompliance — two required slots', () {
    test('cook cannot operate until both slots approved (and not expired)', () {
      final rows = CookRequiredDocumentTypes.latestRowPerRequiredSlot([
        {'document_type': 'id_document', 'status': 'approved', 'no_expiry': true},
        {'document_type': 'health_or_kitchen_document', 'status': 'pending_review'},
      ]);
      expect(rows.length, 2);
      final c = ChefDocumentsCompliance.evaluate([
        {'document_type': 'id_document', 'status': 'approved', 'no_expiry': true},
        {'document_type': 'health_or_kitchen_document', 'status': 'pending_review'},
      ]);
      expect(c.canReceiveOrders, false);
    });

    test('both approved + valid => can receive orders', () {
      final c = ChefDocumentsCompliance.evaluate([
        {'document_type': 'id_document', 'status': 'approved', 'no_expiry': true},
        {'document_type': 'health_or_kitchen_document', 'status': 'approved', 'no_expiry': true},
      ]);
      expect(c.canReceiveOrders, true);
    });

    test('one approved + one rejected => needs resubmission (aggregate)', () {
      final latest = latestRequiredDocumentRowsBySlot([
        {'document_type': 'id_document', 'status': 'approved', 'no_expiry': true},
        {'document_type': 'health_or_kitchen_document', 'status': 'rejected', 'rejection_reason': 'bad scan'},
      ]);
      expect(computeApplicationOverallStatus(latest), AdminApplicationOverallStatus.needsResubmission);
      final c = ChefDocumentsCompliance.evaluate([
        {'document_type': 'id_document', 'status': 'approved', 'no_expiry': true},
        {'document_type': 'health_or_kitchen_document', 'status': 'rejected', 'rejection_reason': 'bad scan'},
      ]);
      expect(c.canReceiveOrders, false);
    });

    test('any rejected document blocks operational access', () {
      final c = ChefDocumentsCompliance.evaluate([
        {'document_type': 'id_document', 'status': 'rejected', 'rejection_reason': 'x'},
        {'document_type': 'health_or_kitchen_document', 'status': 'approved', 'no_expiry': true},
      ]);
      expect(c.canReceiveOrders, false);
    });
  });

  group('apply_chef_document_review dedupe (policy simulation)', () {
    test('approve path: first attempt inserts one admin_document notification key', () {
      final keys = <String>{};
      const docId = 'e0a00001-0000-4000-8d00-000000000003';
      expect(
        _shouldInsertAdminDocumentNotification(
          existingKeys: keys,
          documentId: docId,
        ),
        true,
      );
      keys.add(docId);
      expect(
        _shouldInsertAdminDocumentNotification(
          existingKeys: keys,
          documentId: docId,
        ),
        false,
      );
    });

    test('retry approve does not add a second notification for the same document id', () {
      final keys = <String>{'e0a00001-0000-4000-8d00-000000000003'};
      expect(
        _shouldInsertAdminDocumentNotification(
          existingKeys: keys,
          documentId: 'e0a00001-0000-4000-8d00-000000000003',
        ),
        false,
      );
    });

    test('activation sends once when gate opens and not already present', () {
      expect(
        _shouldInsertActivationNotification(
          alreadyHasChefAccountActivated: false,
          sendActivation: true,
        ),
        true,
      );
      expect(
        _shouldInsertActivationNotification(
          alreadyHasChefAccountActivated: true,
          sendActivation: true,
        ),
        false,
      );
    });

    test('activation system message dedupes on content prefix (SQL NOT EXISTS pattern)', () {
      expect(_shouldInsertActivationSystemMessage(alreadyHasActivationMessage: false), true);
      expect(_shouldInsertActivationSystemMessage(alreadyHasActivationMessage: true), false);
    });
  });
}
