import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';

/// Writes chef online status to Supabase chef_profiles table.
class ChefPresenceDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;

  /// Call when chef opens app or resumes.
  Future<void> setOnline(String chefId, {String? name}) async {
    if (chefId.isEmpty) return;
    await _sb.from('chef_profiles').update({'is_online': true}).eq('id', chefId);
  }

  /// Call when chef closes app or logs out.
  Future<void> setOffline(String chefId) async {
    if (chefId.isEmpty) return;
    await _sb.from('chef_profiles').update({'is_online': false}).eq('id', chefId);
  }
}
