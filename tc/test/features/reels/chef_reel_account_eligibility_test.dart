import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

/// [chefReelAccountEligibleForPublicFeed] — approved, not suspended, not frozen.
void main() {
  ChefDocModel base({
    String? approvalStatus,
    bool suspended = false,
    DateTime? freezeUntil,
  }) {
    return ChefDocModel(
      chefId: 'c',
      kitchenName: 'K',
      approvalStatus: approvalStatus ?? 'approved',
      suspended: suspended,
      freezeUntil: freezeUntil,
    );
  }

  group('chefReelAccountEligibleForPublicFeed', () {
    test('approved with no freeze => eligible', () {
      expect(chefReelAccountEligibleForPublicFeed(base()), isTrue);
    });

    test('not approved => ineligible', () {
      expect(chefReelAccountEligibleForPublicFeed(base(approvalStatus: 'pending')), isFalse);
    });

    test('suspended => ineligible', () {
      expect(chefReelAccountEligibleForPublicFeed(base(suspended: true)), isFalse);
    });

    test('active freeze => ineligible', () {
      expect(
        chefReelAccountEligibleForPublicFeed(
          base(freezeUntil: DateTime.now().add(const Duration(days: 1))),
        ),
        isFalse,
      );
    });
  });
}
