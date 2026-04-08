import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-side expiry handling ([notify_expired_chef_documents] in Supabase).
/// Safe to call often; duplicates are prevented per [chef_documents] row.
abstract final class ChefExpiredDocumentsNotify {
  ChefExpiredDocumentsNotify._();

  static Future<void> ping(SupabaseClient client) async {
    if (client.auth.currentUser == null) return;
    try {
      await client.rpc<void>('notify_expired_chef_documents');
    } catch (e, st) {
      debugPrint('[ChefExpiredDocumentsNotify] $e\n$st');
    }
  }
}
