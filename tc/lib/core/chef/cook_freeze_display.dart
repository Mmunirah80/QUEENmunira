import 'package:intl/intl.dart';

/// User-facing copy for Cook freeze banner (English only).
abstract final class CookFreezeDisplay {
  static String frozenUntilDate(DateTime untilUtc) {
    return DateFormat.yMMMd().format(untilUtc.toLocal());
  }

  /// Remaining time with explicit wording (avoids ambiguous bare numbers).
  static String timeRemainingVerbose(DateTime untilUtc) {
    final diff = untilUtc.difference(DateTime.now());
    if (diff.isNegative) return 'Freeze period ended';
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} remaining';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} remaining';
    }
    return 'Less than 1 hour remaining';
  }

  /// Planned freeze length when start/end are known (e.g. "Frozen for 14 days").
  static String? freezePeriodPlannedLabel({
    DateTime? freezeStartedAt,
    DateTime? freezeUntil,
    String? freezeType,
  }) {
    if (freezeStartedAt != null && freezeUntil != null) {
      final d = freezeUntil.difference(freezeStartedAt).inDays;
      if (d > 0) {
        return 'Frozen for $d day${d == 1 ? '' : 's'}';
      }
    }
    final ft = (freezeType ?? '').toLowerCase().trim();
    if (ft.contains('14') || ft == 'freeze_14d') return 'Frozen for 14 days';
    if (ft.contains('7') || ft == 'freeze_7d') return 'Frozen for 7 days';
    if (ft.contains('3') || ft == 'freeze_3d') return 'Frozen for 3 days';
    if (ft == 'hard') return 'Hard freeze';
    if (ft == 'soft') return 'Soft freeze';
    return null;
  }

  static String freezeModeLabel(String? freezeType) {
    final t = (freezeType ?? 'soft').toLowerCase().trim();
    if (t == 'hard') return 'Hard freeze';
    return 'Soft freeze';
  }
}
