import '../../../../core/chef/chef_availability.dart';

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
  /// Approval status for chef onboarding (approval_status).
  final String? approvalStatus;
  /// Number of warnings from admin (warning_count).
  final int warningCount;
  /// When account is frozen until (freeze_until).
  final DateTime? freezeUntil;
  /// Raw working hours jsonb from Supabase: { "Mon": { "open": "09:00", "close": "21:00" }, ... }.
  final Map<String, dynamic>? workingHours;
  /// Admin moderation: hide from customers and lock main tabs until cleared.
  final bool suspended;
  /// Shown when [suspended] (e.g. document rejected).
  final String? suspensionReason;

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
    this.approvalStatus,
    this.warningCount = 0,
    this.freezeUntil,
    this.workingHours,
    this.suspended = false,
    this.suspensionReason,
  });

  /// Storefront visibility: vacation → hours → open toggle (see [evaluateChefStorefront]).
  ChefStorefrontEvaluation get storefrontEvaluation => evaluateChefStorefront(
        vacationMode: vacationMode,
        isOnline: isOnline,
        workingHoursStart: workingHoursStart,
        workingHoursEnd: workingHoursEnd,
        workingHoursJson: workingHours,
        vacationRangeStart: vacationStart,
        vacationRangeEnd: vacationEnd,
      );

  String get workingHoursDisplay {
    if (workingHours != null && workingHours!.isNotEmpty) {
      final now = DateTime.now();
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      const keys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final key = keys[(weekday - 1).clamp(0, 6)];
      final day = workingHours![key];
      if (day is Map) {
        final open = day['open'] as String?;
        final close = day['close'] as String?;
        if (open != null && close != null && open.isNotEmpty && close.isNotEmpty) {
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

    return ChefDocModel(
      chefId: row['id'] as String?,
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
      kitchenCity: row['kitchen_city'] as String?,
      kitchenLatitude: (row['kitchen_latitude'] as num?)?.toDouble(),
      kitchenLongitude: (row['kitchen_longitude'] as num?)?.toDouble(),
      ratingAvg: (row['rating_avg'] as num?)?.toDouble(),
      totalOrders: (row['total_orders'] as num?)?.toInt(),
      approvalStatus: row['approval_status'] as String?,
      warningCount: (row['warning_count'] as num?)?.toInt() ?? 0,
      freezeUntil: freeze,
      workingHours: row['working_hours'] as Map<String, dynamic>?,
      suspended: row['suspended'] as bool? ?? false,
      suspensionReason: row['suspension_reason'] as String?,
    );
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
