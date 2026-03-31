import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../models/chef_doc_model.dart';

/// Reads/updates chef_profiles via Supabase (kept name for backwards compatibility).
class ChefFirebaseDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;

  /// For customer: stream of all chefs (id, kitchenName, isOnline, vacationMode). Active = !vacationMode.
  Stream<List<ChefDocModel>> watchAllChefs() {
    return _sb
        .from('chef_profiles')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .map((r) => ChefDocModel.fromSupabase(r as Map<String, dynamic>))
            .toList());
  }

  /// Real-time stream of chef document (isOnline, workingHours, dailyCapacity, kitchenName).
  Stream<ChefDocModel?> watchChefDoc(String chefId) {
    if (chefId.isEmpty) return const Stream<ChefDocModel?>.empty();
    return _sb
        .from('chef_profiles')
        .stream(primaryKey: ['id'])
        .eq('id', chefId)
        .map((rows) {
      if (rows.isEmpty) return null;
      return ChefDocModel.fromSupabase(rows.first as Map<String, dynamic>);
    });
  }

  /// Update working hours for today (or default). Shape: { start: "16:00", end: "22:00" }.
  Future<void> updateWorkingHours(
    String chefId, {
    required String start,
    required String end,
  }) async {
    if (chefId.isEmpty) return;
    print('[ChefFirebaseDataSource] updateWorkingHours chefId=$chefId start=$start end=$end');
    await _sb.from('chef_profiles').update({
      'working_hours_start': start,
      'working_hours_end': end,
    }).eq('id', chefId);
  }

  /// Merge-update chef profile: kitchenName, vacationMode.
  Future<void> updateChefProfile(
    String chefId, {
    String? kitchenName,
    bool? vacationMode,
    String? bio,
    String? kitchenCity,
    double? kitchenLatitude,
    double? kitchenLongitude,
  }) async {
    if (chefId.isEmpty) return;
    print('[ChefFirebaseDataSource] updateChefProfile chefId=$chefId kitchenName=$kitchenName vacationMode=$vacationMode');
    final updates = <String, dynamic>{};
    if (kitchenName != null) updates['kitchen_name'] = kitchenName;
    if (vacationMode != null) updates['vacation_mode'] = vacationMode;
    if (bio != null) updates['bio'] = bio;
    if (kitchenCity != null) updates['kitchen_city'] = kitchenCity;
    if (kitchenLatitude != null) updates['kitchen_latitude'] = kitchenLatitude;
    if (kitchenLongitude != null) updates['kitchen_longitude'] = kitchenLongitude;
    if (updates.isEmpty) return;
    await _sb.from('chef_profiles').update(updates).eq('id', chefId);
  }

  /// Update bank details (stored in chef doc).
  Future<void> updateBankDetails(
    String chefId, {
    String? iban,
    String? accountName,
  }) async {
    if (chefId.isEmpty) return;
    print('[ChefFirebaseDataSource] updateBankDetails chefId=$chefId iban=$iban accountName=$accountName');
    final updates = <String, dynamic>{};
    if (iban != null) updates['bank_iban'] = iban;
    if (accountName != null) updates['bank_account_name'] = accountName;
    if (updates.isEmpty) return;
    await _sb.from('chef_profiles').update(updates).eq('id', chefId);
  }

  /// Set online status to true.
  Future<void> setOnline(String chefId) async {
    if (chefId.isEmpty) return;
    print('[ChefFirebaseDataSource] setOnline chefId=$chefId');
    await _sb.from('chef_profiles').update({'is_online': true}).eq('id', chefId);
  }

  /// Set online status to false.
  Future<void> setOffline(String chefId) async {
    if (chefId.isEmpty) return;
    print('[ChefFirebaseDataSource] setOffline chefId=$chefId');
    await _sb.from('chef_profiles').update({'is_online': false}).eq('id', chefId);
  }

  /// Toggle vacation mode.
  Future<void> toggleVacation(String chefId, bool vacationMode) async {
    if (chefId.isEmpty) return;
    print('[ChefFirebaseDataSource] toggleVacation chefId=$chefId vacationMode=$vacationMode');
    await _sb.from('chef_profiles')
        .update({'vacation_mode': vacationMode}).eq('id', chefId);
  }

  /// Replace full working_hours jsonb.
  Future<void> setWorkingHours(String chefId, Map<String, dynamic> workingHours) async {
    if (chefId.isEmpty) return;
    print('[ChefFirebaseDataSource] setWorkingHours chefId=$chefId workingHoursKeys=${workingHours.keys.toList()}');
    await _sb
        .from('chef_profiles')
        .update({'working_hours': workingHours}).eq('id', chefId);
  }

  /// Set full daily capacity. Map: dishId -> { total: int, remaining: int }.
  Future<void> setDailyCapacity(
    String chefId,
    Map<String, Map<String, int>> capacity,
  ) async {
    if (chefId.isEmpty) return;
    final daily = <String, int>{};
    final remaining = <String, int>{};
    capacity.forEach((dishId, caps) {
      final total = caps['total'] ?? 0;
      final rem = caps['remaining'] ?? total;
      daily[dishId] = total;
      remaining[dishId] = rem;
    });
    await _sb.from('chef_profiles').update({
      'daily_capacity': daily,
      'remaining_capacity': remaining,
    }).eq('id', chefId);
  }

  /// Decrement remaining for a dish (e.g. when order is accepted). Returns new remaining or null if not found.
  Future<int?> decrementRemaining(String chefId, String dishId, int by) async {
    if (chefId.isEmpty || dishId.isEmpty || by <= 0) return null;
    final row = await _sb
        .from('chef_profiles')
        .select('remaining_capacity')
        .eq('id', chefId)
        .maybeSingle();
    if (row == null) return null;
    final remRaw = row['remaining_capacity'];
    if (remRaw is! Map) return null;
    final current = (remRaw[dishId] as num?)?.toInt() ?? 0;
    final next = current - by;
    final newRemaining = next < 0 ? 0 : next;
    remRaw[dishId] = newRemaining;
    await _sb
        .from('chef_profiles')
        .update({'remaining_capacity': remRaw}).eq('id', chefId);
    return newRemaining;
  }
}
