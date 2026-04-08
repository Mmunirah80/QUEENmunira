import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/customer/domain/customer_reel_feed_visibility.dart';

/// Matrix for reels eligibility (chef standing + row flags + geography).
void main() {
  const riyadhLat = 24.7136;
  const riyadhLng = 46.6753;

  ChefDocModel approvedChefWithPin({
    bool suspended = false,
    String approvalStatus = 'approved',
    DateTime? freezeUntil,
    String? kitchenCity = 'Riyadh',
    double? kitchenLatitude,
    double? kitchenLongitude,
  }) {
    return ChefDocModel(
      chefId: 'chef1',
      kitchenName: 'K',
      kitchenCity: kitchenCity,
      kitchenLatitude: kitchenLatitude ?? 24.74,
      kitchenLongitude: kitchenLongitude ?? 46.72,
      approvalStatus: approvalStatus,
      suspended: suspended,
      freezeUntil: freezeUntil,
    );
  }

  Map<String, dynamic> activeReelRow() => <String, dynamic>{
        'id': 'r1',
        'is_active': true,
      };

  group('customerCanSeeReelInFeed', () {
    test('E.14 eligible chef + active visible row + matching geography → visible', () {
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(),
          reelRow: activeReelRow(),
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isTrue,
      );
    });

    test('E.15 unapproved chef → hidden even if geography matches', () {
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(approvalStatus: 'pending'),
          reelRow: activeReelRow(),
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });

    test('E.16 frozen chef → hidden', () {
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(
            freezeUntil: DateTime.now().add(const Duration(days: 7)),
          ),
          reelRow: activeReelRow(),
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });

    test('E.17 suspended chef → hidden', () {
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(suspended: true),
          reelRow: activeReelRow(),
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });

    test('E.18 hidden reel row → hidden', () {
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(),
          reelRow: <String, dynamic>{'is_hidden': true, 'is_active': true},
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });

    test('E.19 soft-deleted reel row → hidden', () {
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(),
          reelRow: <String, dynamic>{
            'deleted_at': DateTime.utc(2025, 6, 1).toIso8601String(),
          },
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });

    test('no kitchen map pin → hidden (discovery alignment)', () {
      final chef = ChefDocModel(
        chefId: 'n',
        kitchenName: 'N',
        kitchenCity: 'Riyadh',
        approvalStatus: 'approved',
      );
      expect(
        customerCanSeeReelInFeed(
          chef: chef,
          reelRow: activeReelRow(),
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });

    test('is_active false on reel row hides even when chef and geography match', () {
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(),
          reelRow: <String, dynamic>{'is_active': false},
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });

    test('wrong city vs pickup → hidden when kitchen is another city', () {
      // Same-city filter excludes Jeddah when pickup locality is Riyadh (no cross-city listing).
      expect(
        customerCanSeeReelInFeed(
          chef: approvedChefWithPin(
            kitchenCity: 'Jeddah',
            kitchenLatitude: 21.5,
            kitchenLongitude: 39.2,
          ),
          reelRow: activeReelRow(),
          customerLat: riyadhLat,
          customerLng: riyadhLng,
          pickupLocalityCity: 'Riyadh',
        ),
        isFalse,
      );
    });
  });
}
