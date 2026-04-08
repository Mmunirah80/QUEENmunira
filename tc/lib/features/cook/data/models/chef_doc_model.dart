import '../../../../core/chef/chef_availability.dart';
import '../../../../core/constants/demo_location.dart';

/// Snapshot of chef_profiles row for cook home/profile screens.
class ChefDocModel {
  /// Document id (chefId).
  final String? chefId;
  final bool isOnline;
  final String? kitchenName;
  final String? workingHoursStart;
  final String? workingHoursEnd;
  final bool vacationMode;
  /// Optional scheduled vacation range (see `vacation_mode`); inclusive dates.
  final DateTime? vacationStart;
  final DateTime? vacationEnd;
  final Map<String, DishCapacityModel> dailyCapacity;
  final String? bankIban;
  final String? bankAccountName;
  /// From chef_profiles.bio (optional).
  final String? bio;
  /// From chef_profiles.kitchen_city (optional).
  final String? kitchenCity;
  /// Pickup latitude (WGS84), optional until cook sets pin.
  final double? kitchenLatitude;
  /// Pickup longitude (WGS84).
  final double? kitchenLongitude;
  /// Average rating from orders (rating_avg).
  final double? ratingAvg;
  /// Total completed orders (total_orders).
  final int? totalOrders;
  /// From [chef_profiles.access_level] (server).
  final String? accessLevel;
  /// Storefront / orders gate from [chef_profiles.documents_operational_ok].
  final bool documentsOperationalOk;
  /// Legacy display field.
  final String? approvalStatus;
  /// Number of warnings from admin (warning_count).
  final int warningCount;
  /// Escalation tier after freezes (see `chef_profiles.freeze_level`).
  final int freezeLevel;
  /// When account is frozen until (freeze_until).
  final DateTime? freezeUntil;
  /// When the current freeze was applied.
  final DateTime? freezeStartedAt;
  /// `soft` (default) or `hard` (severe).
  final String? freezeType;
  /// Optional admin note for the Cook.
  final String? freezeReason;
  /// Raw working hours jsonb from Supabase: { "Mon": { "open": "09:00", "close": "21:00" }, ... }.
  final Map<String, dynamic>? workingHours;
  /// Admin moderation: hide from customers and lock main tabs until cleared.
  final bool suspended;
  /// Shown when [suspended] (e.g. document rejected).
  final String? suspensionReason;
  /// First time all required docs were approved; renewal review keeps full shell while [approvalStatus] stays `approved`.
  final DateTime? initialApprovalAt;
  /// Countable random-inspection violations (legacy counter).
  final int inspectionViolationCount;
  /// Inspection ladder step 0–6 (server).
  final int inspectionPenaltyStep;

  const ChefDocModel({
    this.chefId,
    this.isOnline = false,
    this.kitchenName,
    this.workingHoursStart,
    this.workingHoursEnd,
    this.vacationMode = false,
    this.vacationStart,
    this.vacationEnd,
    this.dailyCapacity = const {},
    this.bankIban,
    this.bankAccountName,
    this.bio,
    this.kitchenCity,
    this.kitchenLatitude,
    this.kitchenLongitude,
    this.ratingAvg,
    this.totalOrders,
    this.accessLevel,
    this.documentsOperationalOk = false,
    this.approvalStatus,
    this.warningCount = 0,
    this.freezeLevel = 0,
    this.freezeUntil,
    this.freezeStartedAt,
    this.freezeType,
    this.freezeReason,
    this.workingHours,
    this.suspended = false,
    this.suspensionReason,
    this.initialApprovalAt,
    this.inspectionViolationCount = 0,
    this.inspectionPenaltyStep = 0,
  });

  bool get isFreezeActive {
    final u = freezeUntil;
    return u != null && u.isAfter(DateTime.now());
  }

  bool get isHardFreezeActive {
    if (!isFreezeActive) return false;
    return (freezeType ?? '').toLowerCase().trim() == 'hard';
  }

  /// Kitchen map pin set — required for customer discovery (distance / area matching).
  bool get hasKitchenMapPin =>
      kitchenLatitude != null && kitchenLongitude != null;

  /// Storefront visibility: freeze → vacation → hours → open toggle (see [evaluateChefStorefront]).
  ChefStorefrontEvaluation get storefrontEvaluation => evaluateChefStorefront(
        vacationMode: vacationMode,
        isOnline: isOnline,
        workingHoursStart: workingHoursStart,
        workingHoursEnd: workingHoursEnd,
        workingHoursJson: workingHours,
        vacationRangeStart: vacationStart,
        vacationRangeEnd: vacationEnd,
        freezeUntil: freezeUntil,
        freezeType: freezeType,
      );

  String get workingHoursDisplay {
    final wh = workingHours;
    if (wh != null && wh.isNotEmpty) {
      final now = DateTime.now();
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      const keys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final key = keys[(weekday - 1).clamp(0, 6)];
      final day = wh[key];
      if (day is Map) {
        final open = day['open']?.toString();
        final close = day['close']?.toString();
        if (open != null &&
            close != null &&
            open.isNotEmpty &&
            close.isNotEmpty) {
          return '$open – $close';
        }
      }
    }
    if (workingHoursStart == null || workingHoursEnd == null) return '—';
    return '$workingHoursStart – $workingHoursEnd';
  }

  /// Build from a Supabase chef_profiles row.
  factory ChefDocModel.fromSupabase(Map<String, dynamic> row) {
    final dailyRaw = row['daily_capacity'];
    final remainingRaw = row['remaining_capacity'];
    final Map<String, DishCapacityModel> capacities = {};
    if (dailyRaw is Map) {
      final remMap = remainingRaw is Map
          ? Map<dynamic, dynamic>.from(remainingRaw)
          : <dynamic, dynamic>{};
      dailyRaw.forEach((key, value) {
        final total = (value as num?)?.toInt() ?? 0;
        final remaining = (remMap[key] as num?)?.toInt() ?? total;
        capacities[key.toString()] =
            DishCapacityModel(total: total, remaining: remaining);
      });
    }

    DateTime? freeze;
    final freezeRaw = row['freeze_until'];
    if (freezeRaw is DateTime) {
      freeze = freezeRaw;
    } else if (freezeRaw is String) {
      freeze = DateTime.tryParse(freezeRaw);
    }

    DateTime? freezeStarted;
    final fsRaw = row['freeze_started_at'];
    if (fsRaw is DateTime) {
      freezeStarted = fsRaw;
    } else if (fsRaw is String) {
      freezeStarted = DateTime.tryParse(fsRaw);
    }

    DateTime? initialApproval;
    final ia = row['initial_approval_at'];
    if (ia is DateTime) {
      initialApproval = ia;
    } else if (ia is String) {
      initialApproval = DateTime.tryParse(ia);
    }

    return ChefDocModel(
      chefId: row['id']?.toString(),
      isOnline: row['is_online'] as bool? ?? false,
      kitchenName: row['kitchen_name'] as String?,
      workingHoursStart: row['working_hours_start'] as String?,
      workingHoursEnd: row['working_hours_end'] as String?,
      vacationMode: row['vacation_mode'] as bool? ?? false,
      vacationStart: _parseDateOnly(row['vacation_start']),
      vacationEnd: _parseDateOnly(row['vacation_end']),
      dailyCapacity: capacities,
      bankIban: row['bank_iban'] as String?,
      bankAccountName: row['bank_account_name'] as String?,
      bio: row['bio'] as String?,
      kitchenCity: effectiveKitchenCityForDisplay(row['kitchen_city'] as String?),
      kitchenLatitude: (row['kitchen_latitude'] as num?)?.toDouble(),
      kitchenLongitude: (row['kitchen_longitude'] as num?)?.toDouble(),
      ratingAvg: (row['rating_avg'] as num?)?.toDouble(),
      totalOrders: (row['total_orders'] as num?)?.toInt(),
      accessLevel: row['access_level'] as String?,
      documentsOperationalOk: row['documents_operational_ok'] as bool? ?? false,
      approvalStatus: row['approval_status'] as String?,
      warningCount: (row['warning_count'] as num?)?.toInt() ?? 0,
      freezeLevel: (row['freeze_level'] as num?)?.toInt() ?? 0,
      freezeUntil: freeze,
      freezeStartedAt: freezeStarted,
      freezeType: row['freeze_type'] as String?,
      freezeReason: row['freeze_reason'] as String?,
      workingHours: _jsonMapOrNull(row['working_hours']),
      suspended: row['suspended'] as bool? ?? false,
      suspensionReason: row['suspension_reason'] as String?,
      initialApprovalAt: initialApproval,
      inspectionViolationCount: (row['inspection_violation_count'] as num?)?.toInt() ?? 0,
      inspectionPenaltyStep: (row['inspection_penalty_step'] as num?)?.toInt() ?? 0,
    );
  }

  /// Accepts JSON maps with non-String keys (Postgres/Supabase may return Map<dynamic,dynamic>).
  static Map<String, dynamic>? _jsonMapOrNull(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      try {
        return v.map((key, val) => MapEntry(key.toString(), val));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static DateTime? _parseDateOnly(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return DateTime(v.year, v.month, v.day);
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }
    return null;
  }
}

class DishCapacityModel {
  final int total;
  final int remaining;

  const DishCapacityModel({required this.total, required this.remaining});
}
