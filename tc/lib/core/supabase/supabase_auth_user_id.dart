import 'package:supabase_flutter/supabase_flutter.dart';

/// Authenticated user id from [client] (matches JWT `sub` / RLS `auth.uid()`).
String? supabaseAuthUserId(SupabaseClient client) {
  final raw = client.auth.currentUser?.id;
  if (raw == null || raw.isEmpty) return null;
  return raw.trim();
}
