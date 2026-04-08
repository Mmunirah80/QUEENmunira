import 'package:flutter_test/flutter_test.dart';

import 'support/chef_document_review_simulator.dart';

void main() {
  group('ChefDocumentReviewSimulator — individual admin review', () {
    test('approve document A only — A approved, B unchanged', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
      });

      sim.approve('national_id');

      expect(sim.row('national_id')!['status'], 'approved');
      expect(sim.row('freelancer_id')!['status'], 'pending_review');
      expect(sim.compliance().canReceiveOrders, isFalse);
    });

    test('reject document B only — B rejected with reason, A unchanged', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'approved',
          'no_expiry': true,
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
      });

      sim.reject('freelancer_id', 'Photo unreadable');

      expect(sim.row('national_id')!['status'], 'approved');
      expect(sim.row('freelancer_id')!['status'], 'rejected');
      expect(sim.row('freelancer_id')!['rejection_reason'], 'Photo unreadable');
    });

    test('approve required types in any order — both approved => operational compliance', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
      });

      sim.approve('freelancer_id');
      expect(sim.compliance().canReceiveOrders, isFalse);

      sim.approve('national_id');
      expect(sim.compliance().canReceiveOrders, isTrue);
    });

    test('reviewing one document does not mutate the other document row', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
      });

      final beforeOther = Map<String, dynamic>.from(sim.row('freelancer_id')!);
      sim.approve('national_id');
      expect(sim.row('freelancer_id'), beforeOther);
    });
  });

  group('ChefDocumentReviewSimulator — rejection / re-upload', () {
    test('rejected document exposes rejection reason to compliance row map', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'approved',
          'no_expiry': true,
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
      });
      sim.reject('freelancer_id', 'Blurry scan');
      expect(sim.row('freelancer_id')!['rejection_reason'], 'Blurry scan');
    });

    test('re-upload supersedes rejected row: pending_review clears reason for new review cycle', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'rejected',
          'no_expiry': true,
          'rejection_reason': 'Old reason',
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'approved',
          'no_expiry': true,
        },
      });

      sim.chefResubmit('national_id');
      expect(sim.row('national_id')!['status'], 'pending_review');
      expect(sim.row('national_id')!['rejection_reason'], isNull);

      sim.approve('national_id');
      expect(sim.compliance().canReceiveOrders, isTrue);
    });

    test('after re-upload admin can approve independently of order of other doc', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'rejected',
          'no_expiry': true,
          'rejection_reason': 'x',
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'approved',
          'no_expiry': true,
        },
      });
      sim.chefResubmit('national_id');
      sim.approve('national_id');
      expect(sim.compliance().canReceiveOrders, isTrue);
    });
  });

  group('ChefDocumentReviewSimulator — mixed churn', () {
    test('multiple updates keep per-type state consistent', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'pending_review',
          'no_expiry': true,
        },
      });
      sim.approve('national_id');
      sim.reject('freelancer_id', 'First reject');
      sim.chefResubmit('freelancer_id');
      sim.approve('freelancer_id');
      expect(sim.compliance().canReceiveOrders, isTrue);
    });

    test('re-approve already approved is idempotent for compliance', () {
      final sim = ChefDocumentReviewSimulator({
        'national_id': {
          'document_type': 'national_id',
          'status': 'approved',
          'no_expiry': true,
        },
        'freelancer_id': {
          'document_type': 'freelancer_id',
          'status': 'approved',
          'no_expiry': true,
        },
      });
      sim.approve('national_id');
      expect(sim.compliance().canReceiveOrders, isTrue);
    });
  });
}
