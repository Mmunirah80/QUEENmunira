import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/chef/chef_availability.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/reels/domain/reel_public_feed_visibility.dart';

import 'support/cross_role_sync_stores.dart';

/// C.12–14 + D.14: shared chef profile + reel rows; customer vs chef vs admin views.
void main() {
  const chefId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const customerLat = 24.7;
  const customerLng = 46.7;

  Map<String, dynamic> chefRowRiyadh() {
    return {
      'id': chefId,
      'kitchen_name': 'Kitchen',
      'is_online': true,
      'vacation_mode': false,
      'vacation_start': null,
      'vacation_end': null,
      'working_hours_start': '09:00',
      'working_hours_end': '22:00',
      'working_hours': null,
      'suspended': false,
      'approval_status': 'approved',
      'access_level': 'full_access',
      'documents_operational_ok': true,
      'kitchen_city': 'Riyadh',
      'kitchen_latitude': 24.72,
      'kitchen_longitude': 46.68,
      'freeze_until': null,
      'freeze_type': null,
    };
  }

  group('ChefProfileSyncStore — location change visible to discovery', () {
    test('chef moves pin → customer home geography includes kitchen at new coords', () {
      final store = ChefProfileSyncStore(chefRowRiyadh());
      expect(
        chefVisibleForCustomerHome(store.doc, customerLat, customerLng, 'Riyadh'),
        isTrue,
      );

      store.patch({
        'kitchen_latitude': 21.5,
        'kitchen_longitude': 39.2,
        'kitchen_city': 'Jeddah',
      });

      expect(
        chefVisibleForCustomerHome(store.doc, customerLat, customerLng, 'Riyadh'),
        isFalse,
      );
      expect(
        chefVisibleForCustomerHome(store.doc, 21.5, 39.2, 'Jeddah'),
        isTrue,
      );
    });
  });

  group('ReelModerationSyncStore — admin remove/hide propagates to customer feed', () {
    test('admin deletes reel → customer public feed predicate excludes it', () {
      final store = ReelModerationSyncStore([
        {
          'id': 'r1',
          'chef_id': chefId,
          'is_active': true,
        },
      ]);
      expect(store.customerPublicFeedRows().length, 1);

      store.adminSoftDelete('r1');
      expect(store.customerPublicFeedRows(), isEmpty);
      expect(isReelRowPublicFeedVisible(store.reels.first), isFalse);
    });

    test('chef still sees row with deleted_at in management list (raw row exists)', () {
      final store = ReelModerationSyncStore([
        {'id': 'r2', 'chef_id': chefId, 'is_active': true},
      ]);
      store.adminSoftDelete('r2');
      final raw = store.chefRowById(chefId, 'r2');
      expect(raw, isNotNull);
      expect(raw!['deleted_at'], isNotNull);
    });
  });

  group('ChefProfileSyncStore — freeze blocks storefront acceptance (fixed clock)', () {
    test('admin sets freeze_until → evaluateChefStorefront reports frozen for chef and customer policy', () {
      final store = ChefProfileSyncStore(chefRowRiyadh());
      final until = DateTime(2026, 6, 1, 12, 0);
      store.patch({
        'freeze_until': until.toIso8601String(),
        'freeze_type': 'soft',
      });

      final doc = store.doc;
      final ev = evaluateChefStorefront(
        vacationMode: doc.vacationMode,
        isOnline: doc.isOnline,
        workingHoursStart: doc.workingHoursStart,
        workingHoursEnd: doc.workingHoursEnd,
        workingHoursJson: doc.workingHours,
        vacationRangeStart: doc.vacationStart,
        vacationRangeEnd: doc.vacationEnd,
        freezeUntil: doc.freezeUntil,
        freezeType: doc.freezeType,
        now: DateTime(2026, 3, 1, 10, 0),
      );
      expect(ev.isAcceptingOrders, isFalse);
      expect(ev.reason, ChefStorefrontReason.frozen);
    });
  });
}
