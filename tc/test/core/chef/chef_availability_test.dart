import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/chef/chef_availability.dart';

void main() {
  // Monday 23 Mar 2026, 10:00 local
  final mon1000 = DateTime(2026, 3, 23, 10, 0);

  group('evaluateChefStorefront', () {
    test('vacation flag closes regardless of hours and toggle', () {
      final e = evaluateChefStorefront(
        vacationMode: true,
        isOnline: true,
        workingHoursStart: '09:00',
        workingHoursEnd: '18:00',
        workingHoursJson: null,
        now: mon1000,
      );
      expect(e.isAcceptingOrders, false);
      expect(e.reason, ChefStorefrontReason.vacation);
    });

    test('outside working hours closes even when toggle on', () {
      final evening = DateTime(2026, 3, 23, 20, 0);
      final e = evaluateChefStorefront(
        vacationMode: false,
        isOnline: true,
        workingHoursStart: '09:00',
        workingHoursEnd: '18:00',
        workingHoursJson: null,
        now: evening,
      );
      expect(e.isAcceptingOrders, false);
      expect(e.reason, ChefStorefrontReason.outsideWorkingHours);
      expect(e.opensAtLabel, '09:00');
    });

    test('toggle off closes inside hours', () {
      final e = evaluateChefStorefront(
        vacationMode: false,
        isOnline: false,
        workingHoursStart: '09:00',
        workingHoursEnd: '18:00',
        workingHoursJson: null,
        now: mon1000,
      );
      expect(e.isAcceptingOrders, false);
      expect(e.reason, ChefStorefrontReason.offline);
    });

    test('accepting when not on vacation, in hours, toggle on', () {
      final e = evaluateChefStorefront(
        vacationMode: false,
        isOnline: true,
        workingHoursStart: '09:00',
        workingHoursEnd: '18:00',
        workingHoursJson: null,
        now: mon1000,
      );
      expect(e.isAcceptingOrders, true);
      expect(e.reason, ChefStorefrontReason.accepting);
    });

    test('overnight window: late evening counts as inside', () {
      final late = DateTime(2026, 3, 23, 23, 30);
      final e = evaluateChefStorefront(
        vacationMode: false,
        isOnline: true,
        workingHoursStart: '22:00',
        workingHoursEnd: '02:00',
        workingHoursJson: null,
        now: late,
      );
      expect(e.isAcceptingOrders, true);
    });
  });

  group('effectiveVacation', () {
    test('date range without flag', () {
      final start = DateTime(2026, 3, 20);
      final end = DateTime(2026, 3, 25);
      expect(
        effectiveVacation(
          vacationFlag: false,
          vacationRangeStart: start,
          vacationRangeEnd: end,
          now: mon1000,
        ),
        true,
      );
    });
  });
}
