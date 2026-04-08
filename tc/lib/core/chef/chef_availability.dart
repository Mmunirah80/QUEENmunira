/// Single source of truth for "chef visible / accepting orders" on the storefront.
///
/// Rule:
/// - If admin freeze is active (`freeze_until` > now) → not accepting (reason [ChefStorefrontReason.frozen]).
/// - Else: available ⇔ NOT on vacation AND within working hours AND [is_online] is true.
///
/// Debug: set to true temporarily to trace availability bugs (toggle / hours / vacation).
library;

const bool kDebugChefAvailability = false;

void _chefAvailLog(String message) {
  if (kDebugChefAvailability) {
    // ignore: avoid_print
    print('[ChefAvailability] $message');
  }
}

enum ChefStorefrontReason {
  /// Admin freeze active ([freeze_until] in the future). No new orders; Cook UI shows banner.
  frozen,
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
    this.frozenUntil,
    this.freezeType,
  });

  final bool isAcceptingOrders;
  final ChefStorefrontReason reason;

  /// When [reason] is [outsideWorkingHours], today's scheduled open time (24h), if known.
  final String? opensAtLabel;

  /// When [reason] is [frozen], end of freeze (same instant as DB `freeze_until`).
  final DateTime? frozenUntil;

  /// `soft` or `hard` from `chef_profiles.freeze_type` when frozen.
  final String? freezeType;
}

int? _parseTimeToMinutes24h(String? s) {
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

/// Legacy rows saved with locale `TimeOfDay.format` (e.g. `9:00 AM`). Prefer 24h on write.
int? _parseTimeToMinutes12hLegacy(String? s) {
  if (s == null) return null;
  final trimmed = s.trim().replaceAll('\u202f', ' ');
  if (trimmed.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])').firstMatch(trimmed);
  if (m == null) return null;
  var h = int.tryParse(m.group(1)!) ?? 0;
  final min = int.tryParse(m.group(2)!) ?? 0;
  if (min < 0 || min > 59) return null;
  final ap = m.group(3)!.toUpperCase();
  if (ap == 'PM' && h < 12) h += 12;
  if (ap == 'AM' && h == 12) h = 0;
  if (h < 0 || h > 23) return null;
  return h * 60 + min;
}

int? _parseTimeToMinutes(String? s) {
  return _parseTimeToMinutes24h(s) ?? _parseTimeToMinutes12hLegacy(s);
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

  if (workingHoursJson != null && workingHoursJson.isEmpty) {
    return null;
  }

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
  _chefAvailLog(
    'isWithinWorkingHours now=$t nowMin=$nowMin weekday=${t.weekday} '
    'legacyStart=$workingHoursStart legacyEnd=$workingHoursEnd '
    'jsonEmpty=${workingHoursJson == null || workingHoursJson.isEmpty}',
  );

  // Saved with all days off → `{}`. Do not fall back to legacy (would look "open").
  if (workingHoursJson != null && workingHoursJson.isEmpty) {
    _chefAvailLog('working_hours empty object -> outside working hours');
    return false;
  }

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
        _chefAvailLog(
          'weekly today open="$open" close="$close" -> minutes a=$a b=$b '
          '(if null, string is not HH:mm — e.g. 12h locale breaks availability)',
        );
        if (a == null || b == null) return false;
        final inside = _minutesWithinWindow(nowMin, a, b);
        _chefAvailLog('weekly window inside=$inside');
        return inside;
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
    _chefAvailLog('legacy columns missing or unparseable -> withinHours=true');
    return true;
  }
  final legacyInside = _minutesWithinWindow(nowMin, s, e);
  _chefAvailLog('legacy window s=$s e=$e inside=$legacyInside');
  return legacyInside;
}

ChefStorefrontEvaluation evaluateChefStorefront({
  required bool vacationMode,
  required bool isOnline,
  required String? workingHoursStart,
  required String? workingHoursEnd,
  required Map<String, dynamic>? workingHoursJson,
  DateTime? vacationRangeStart,
  DateTime? vacationRangeEnd,
  DateTime? freezeUntil,
  String? freezeType,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final fu = freezeUntil;
  if (fu != null && fu.isAfter(t)) {
    final ft = freezeType?.trim();
    final ftNorm = (ft == null || ft.isEmpty) ? null : ft.toLowerCase();
    _chefAvailLog('-> reason=frozen until=$fu type=$ftNorm');
    return ChefStorefrontEvaluation(
      isAcceptingOrders: false,
      reason: ChefStorefrontReason.frozen,
      frozenUntil: fu,
      freezeType: ftNorm,
    );
  }

  final onVacation = effectiveVacation(
    vacationFlag: vacationMode,
    vacationRangeStart: vacationRangeStart,
    vacationRangeEnd: vacationRangeEnd,
    now: t,
  );
  final inHours = isWithinWorkingHours(
    workingHoursJson: workingHoursJson,
    workingHoursStart: workingHoursStart,
    workingHoursEnd: workingHoursEnd,
    now: t,
  );
  final finalAvailable = !onVacation && inHours && isOnline;
  _chefAvailLog(
    'evaluate now=$t isOnVacation=$onVacation vacationMode=$vacationMode '
    'isWithinWorkingHours=$inHours isOnline=$isOnline '
    'finalAcceptingOrders=$finalAvailable',
  );

  if (onVacation) {
    _chefAvailLog('-> reason=vacation');
    return const ChefStorefrontEvaluation(
      isAcceptingOrders: false,
      reason: ChefStorefrontReason.vacation,
    );
  }

  if (!inHours) {
    final opens = todaysOpeningTimeLabel(
      workingHoursJson: workingHoursJson,
      workingHoursStart: workingHoursStart,
      workingHoursEnd: workingHoursEnd,
      now: t,
    );
    _chefAvailLog('-> reason=outsideWorkingHours opensAt=$opens');
    return ChefStorefrontEvaluation(
      isAcceptingOrders: false,
      reason: ChefStorefrontReason.outsideWorkingHours,
      opensAtLabel: opens,
    );
  }

  if (!isOnline) {
    _chefAvailLog('-> reason=offline');
    return const ChefStorefrontEvaluation(
      isAcceptingOrders: false,
      reason: ChefStorefrontReason.offline,
    );
  }

  _chefAvailLog('-> reason=accepting');
  return const ChefStorefrontEvaluation(
    isAcceptingOrders: true,
    reason: ChefStorefrontReason.accepting,
  );
}
