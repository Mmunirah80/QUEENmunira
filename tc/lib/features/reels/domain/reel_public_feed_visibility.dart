/// Row flags for public reels feed (matches RLS / supabase_reels_select_public_chef_guard_v1.sql public branch).
bool isReelRowPublicFeedVisible(Map<String, dynamic> r) {
  final active = r['is_active'] as bool? ?? true;
  if (active == false) return false;
  if (r.containsKey('deleted_at') && r['deleted_at'] != null) return false;
  final hidden = r['is_hidden'] as bool? ?? false;
  if (hidden) return false;
  return true;
}
