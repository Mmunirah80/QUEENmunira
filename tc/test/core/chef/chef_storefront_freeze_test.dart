import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/chef/chef_availability.dart';

void main() {
  group('evaluateChefStorefront — admin freeze', () {
    final fixedNow = DateTime(2026, 4, 6, 12, 0);

    test('freeze_until after now → not accepting, reason frozen', () {
      final until = fixedNow.add(const Duration(hours: 2));
      final ev = evaluateChefStorefront(
        vacationMode: false,
        isOnline: true,
        workingHoursStart: '09:00',
        workingHoursEnd: '22:00',
        workingHoursJson: null,
        freezeUntil: until,
        freezeType: 'hard',
        now: fixedNow,
      );
      expect(ev.isAcceptingOrders, isFalse);
      expect(ev.reason, ChefStorefrontReason.frozen);
      expect(ev.frozenUntil, until);
      expect(ev.freezeType, 'hard');
    });

    test('freeze_until in past → normal availability rules apply', () {
      final ev = evaluateChefStorefront(
        vacationMode: false,
        isOnline: true,
        workingHoursStart: '09:00',
        workingHoursEnd: '22:00',
        workingHoursJson: null,
        freezeUntil: fixedNow.subtract(const Duration(minutes: 1)),
        freezeType: 'soft',
        now: fixedNow,
      );
      expect(ev.reason, ChefStorefrontReason.accepting);
      expect(ev.isAcceptingOrders, isTrue);
    });
  });
}
