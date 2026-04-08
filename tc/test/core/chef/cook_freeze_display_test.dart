import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/chef/cook_freeze_display.dart';

void main() {
  test('timeRemainingVerbose uses explicit remaining wording', () {
    final until = DateTime.now().toUtc().add(const Duration(days: 13, hours: 2));
    final s = CookFreezeDisplay.timeRemainingVerbose(until);
    expect(s.contains('remaining'), isTrue);
    expect(s.contains('13'), isTrue);
  });

  test('freezePeriodPlannedLabel from span', () {
    final start = DateTime.utc(2026, 1, 1);
    final end = DateTime.utc(2026, 1, 15);
    final label = CookFreezeDisplay.freezePeriodPlannedLabel(
      freezeStartedAt: start,
      freezeUntil: end,
      freezeType: 'soft',
    );
    expect(label, 'Frozen for 14 days');
  });
}
