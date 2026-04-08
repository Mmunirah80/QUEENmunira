import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/chef/chef_availability.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/customer/data/datasources/customer_browse_supabase_datasource.dart';

/// Mirrors [CustomerBrowseSupabaseDatasource.watchAvailableDishes] chef gate:
/// map pin + storefront accepting + account listings.
void main() {
  Map<String, dynamic> baseProfile({
    double? lat,
    double? lng,
    bool vacation = false,
    bool online = true,
  }) {
    return {
      'id': 'chef1',
      'is_online': online,
      'vacation_mode': vacation,
      'vacation_start': null,
      'vacation_end': null,
      'working_hours_start': '09:00',
      'working_hours_end': '18:00',
      'working_hours': null,
      'suspended': false,
      'approval_status': 'approved',
      'access_level': 'partial_access',
      'documents_operational_ok': true,
      'kitchen_latitude': lat,
      'kitchen_longitude': lng,
      'freeze_until': null,
    };
  }

  test('no kitchen pin → dishes not exposed to browse aggregation', () {
    final row = baseProfile(lat: null, lng: null);
    final doc = ChefDocModel.fromSupabase(row);
    expect(doc.hasKitchenMapPin, isFalse);
    final allowed = doc.hasKitchenMapPin &&
        doc.storefrontEvaluation.isAcceptingOrders &&
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings(row);
    expect(allowed, isFalse);
  });

  test('pin + approved + in hours + online → browse gate passes (fixed clock)', () {
    // [ChefDocModel.storefrontEvaluation] uses DateTime.now(); for deterministic tests,
    // mirror browse rules with [evaluateChefStorefront] and an explicit [now].
    final row = baseProfile(lat: 24.7, lng: 46.6);
    final doc = ChefDocModel.fromSupabase(row);
    final mon1000 = DateTime(2026, 3, 23, 10, 0);
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
      now: mon1000,
    );
    final allowed = doc.hasKitchenMapPin &&
        ev.isAcceptingOrders &&
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings(row);
    expect(allowed, isTrue);
  });

  test('vacation blocks storefront even with pin', () {
    final row = baseProfile(lat: 24.7, lng: 46.6, vacation: true);
    final doc = ChefDocModel.fromSupabase(row);
    expect(doc.storefrontEvaluation.isAcceptingOrders, isFalse);
    final allowed = doc.hasKitchenMapPin &&
        doc.storefrontEvaluation.isAcceptingOrders &&
        CustomerBrowseSupabaseDatasource.storefrontAccountAllowsListings(row);
    expect(allowed, isFalse);
  });
}
