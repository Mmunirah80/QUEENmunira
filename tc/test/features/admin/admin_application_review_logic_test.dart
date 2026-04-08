import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/domain/admin_application_review_logic.dart';
import 'package:naham_cook_app/features/cook/data/cook_required_document_types.dart';

void main() {
  group('computeApplicationOverallStatus (two required slots)', () {
    test('any rejected document => needs resubmission', () {
      final latest = latestRequiredDocumentRowsBySlot([
        {
          'document_type': 'id_document',
          'status': 'approved',
          'no_expiry': true,
        },
        {
          'document_type': 'health_or_kitchen_document',
          'status': 'rejected',
          'rejection_reason': 'bad quality',
        },
      ]);
      expect(computeApplicationOverallStatus(latest), AdminApplicationOverallStatus.needsResubmission);
    });

    test('all required approved => approved', () {
      final latest = latestRequiredDocumentRowsBySlot([
        {
          'document_type': 'id_document',
          'status': 'approved',
          'no_expiry': true,
        },
        {
          'document_type': 'health_or_kitchen_document',
          'status': 'approved',
          'no_expiry': true,
        },
      ]);
      expect(computeApplicationOverallStatus(latest), AdminApplicationOverallStatus.approved);
    });

    test('one approved one pending => pending', () {
      final latest = latestRequiredDocumentRowsBySlot([
        {
          'document_type': 'id_document',
          'status': 'approved',
          'no_expiry': true,
        },
        {
          'document_type': 'health_or_kitchen_document',
          'status': 'pending_review',
        },
      ]);
      expect(computeApplicationOverallStatus(latest), AdminApplicationOverallStatus.pending);
    });

    test('legacy national_id + freelancer_id merge to two slots', () {
      final latest = latestRequiredDocumentRowsBySlot([
        {'document_type': 'national_id', 'status': 'approved', 'no_expiry': true},
        {'document_type': 'freelancer_id', 'status': 'pending_review'},
      ]);
      expect(latest.length, 2);
      expect(latest[CookRequiredDocumentTypes.idDocument]!['status'], 'approved');
      expect(computeApplicationOverallStatus(latest), AdminApplicationOverallStatus.pending);
    });
  });
}
