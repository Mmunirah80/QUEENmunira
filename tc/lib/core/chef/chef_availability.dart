/// Single source of truth for "chef visible / accepting orders" on the storefront.
///
/// Rule (same as product spec):
/// available ⇔ NOT on vacation AND within working hours AND [is_online] is true.
library;

enum ChefStorefrontReason {
  accepting,
  vacation,
  outsideWorkingHours,
  offline,
}

class ChefStorefrontEvaluation {
  const ChefStorefrontEvaluation({
    required this.isAcceptingOrders,
    required this.reason,
    this.opensAtLabel,
  });

  final bool isAcceptingOrders;
  final ChefStorefrontReason reason;

  /// When [reason] is [outsideWorkingHours], today's scheduled open time (24h), if known.
  final String? opensAtLabel;
}

int? _parseTimeToMinutes(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty) return null;
  final parts = t.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

bool _minutesWithinWindow(int nowMin, int startMin, int endMin) {
  if (endMin >= startMin) {
    return nowMin >= startMin && nowMin <= endMin;
  }
  // Overnight window (e.g. 22:00–02:00)
  return nowMin >= startMin || nowMin <= endMin;
}

const _weekdayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Map<String, dynamic>? _dayEntryForWeekday(
  Map<String, dynamic> workingHoursJson,
  int weekday,
) {
  // DateTime.weekday mapping:
  // Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6, Sunday=7
  final short = _weekdayKeys[(weekday - 1).clamp(0, 6)];
  final aliases = <String>[
    short,
    short.toLowerCase(),
    short.toUpperCase(),
    '$weekday',
    // full names
    const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][weekday - 1],
    const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][weekday - 1],
    const ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'][weekday - 1],
  ];

  for (final k in aliases) {
    final v = workingHoursJson[k];
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
  }
  return null;
}

/// True if [date] falls on [rangeStart]..[rangeEnd] (date-only, inclusive).
bool isDateInVacationRange(
  DateTime date,
  DateTime? rangeStart,
  DateTime? rangeEnd,
) {
  if (rangeStart == null || rangeEnd == null) return false;
  final d = DateTime(date.year, date.month, date.day);
  final ds = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
  final de = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
  return !d.isBefore(ds) && !d.isAfter(de);
}

bool effectiveVacation({
  required bool vacationFlag,
  DateTime? vacationRangeStart,
  DateTime? vacationRangeEnd,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  if (vacationFlag) return true;
  return isDateInVacationRange(t, vacationRangeStart, vacationRangeEnd);
}

/// Today's opening time label (24h) for hints, or null.
String? todaysOpeningTimeLabel({
  required Map<String, dynamic>? workingHoursJson,
  required String? workingHoursStart,
  required String? workingHoursEnd,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();

  if (workingHoursJson != null && workingHoursJson.isNotEmpty) {
    final day = _dayEntryForWeekday(workingHoursJson, t.weekday);
    if (day != null) {
      final enabled = day['enabled'];
      if (enabled is bool && !enabled) {
        // Today explicitly disabled in weekly schedule.
        return null;
      }
      final open = day['open']?.toString();
      final close = day['close']?.toString();
      if (open != null &&
          close != null &&
          open.trim().isNotEmpty &&
          close.trim().isNotEmpty) {
        return open.trim();
      }
    }
    final start = _parseTimeToMinutes(workingHoursStart);
    if (start != null) return workingHoursStart!.trim();
    return null;
  }

  final start = _parseTimeToMinutes(workingHoursStart);
  if (start == null) return null;
  return workingHoursStart!.trim();
}

bool isWithinWorkingHours({
  required Map<String, dynamic>? workingHoursJson,
  required String? workingHoursStart,
  required String? workingHoursEnd,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final nowMin = t.hour * 60 + t.minute;

  if (workingHoursJson != null && workingHoursJson.isNotEmpty) {
    final day = _dayEntryForWeekday(workingHoursJson, t.weekday);
    if (day != null) {
      final enabled = day['enabled'];
      if (enabled is bool && !enabled) {
        // Today explicitly disabled in weekly schedule.
        return false;
      }
      final open = day['open']?.toString();
      final close = day['close']?.toString();
      if (open != null &&
          close != null &&
          open.trim().isNotEmpty &&
          close.trim().isNotEmpty) {
        final a = _parseTimeToMinutes(open);
        final b = _parseTimeToMinutes(close);
        if (a == null || b == null) return false;
        return _minutesWithinWindow(nowMin, a, b);
      }
    }
    // JSON exists for the week but today has no slot: fall back to legacy columns.
    final legacyStart = _parseTimeToMinutes(workingHoursStart);
    final legacyEnd = _parseTimeToMinutes(workingHoursEnd);
    if (legacyStart != null && legacyEnd != null) {
      return _minutesWithinWindow(nowMin, legacyStart, legacyEnd);
    }
    // Per-day schedule without fallback → treat as closed that day.
    return false;
  }

  final s = _parseTimeToMinutes(workingHoursStart);
  final e = _parseTimeToMinutes(workingHoursEnd);
  if (s == null || e == null) {
    // No schedule configured → do not block (backward compatible with toggle-only kitchens).
    return true;
  }
  return _minutesWithinWindow(nowMin, s, e);
}

ChefStorefrontEvaluation evaluateChefStorefront({
  required bool vacationMode,
  required bool isOnline,
  required String? workingHoursStart,
  required String? workingHoursEnd,
  required Map<String, dynamic>? workingHoursJson,
  DateTime? vacationRangeStart,
  DateTime? vacationRangeEnd,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();

  if (effectiveVacation(
    vacationFlag: vacationMode,
    vacationRangeStart: vacationRangeStart,
    vacationRangeEnd: vacationRangeEnd,
    now: t,
  )) {
    return const ChefStorefrontEvaluation(
      isAcceptingOrders: false,
      reason: ChefStorefrontReason.vacation,
    );
  }

  final inHours = isWithinWorkingHours(
    workingHoursJson: workingHoursJson,
    workingHoursStart: workingHoursStart,
    workingHoursEnd: workingHoursEnd,
    now: t,
  );

  if (!inHours) {
    final opens = todaysOpeningTimeLabel(
      workingHoursJson: workingHoursJson,
      workingHoursStart: workingHoursStart,
      workingHoursEnd: workingHoursEnd,
      now: t,
    );
    return ChefStorefrontEvaluation(
      isAcceptingOrders: false,
      reason: ChefStorefrontReason.outsideWorkingHours,
      opensAtLabel: opens,
    );
  }

  if (!isOnline) {
    return const ChefStorefrontEvaluation(
      isAcceptingOrders: false,
      reason: ChefStorefrontReason.offline,
    );
  }

  return const ChefStorefrontEvaluation(
    isAcceptingOrders: true,
    reason: ChefStorefrontReason.accepting,
  );
}
