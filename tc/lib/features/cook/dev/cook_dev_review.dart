import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';

/// QA: simulate admin document approve/reject from the cook app.
///
/// **Same RPC as admin** ([apply_chef_document_review]) — no duplicate client-side DB writes.
///
/// Enable UI with **debug builds** or:
/// `flutter run --dart-define=COOK_SIMULATE_ADMIN_REVIEW=true`
///
/// **Supabase (staging):** after running `supabase_apply_chef_document_review.sql`, turn on the
/// server gate so chefs may call the RPC on their own pending rows:
/// `UPDATE public.dev_feature_flags SET enabled = true WHERE key = 'chef_document_review_simulation';`
/// Production: keep `enabled = false`.
///
/// Legacy define still works: `COOK_DEV_SIMULATE_REVIEW`.
abstract final class CookDevReview {
  CookDevReview._();

  static SupabaseClient get _client => SupabaseConfig.client;

  static bool get simulationModeEnabled =>
      kDebugMode ||
      const bool.fromEnvironment('COOK_SIMULATE_ADMIN_REVIEW') ||
      const bool.fromEnvironment('COOK_DEV_SIMULATE_REVIEW');

  /// Most recently uploaded pending row for the signed-in chef (same doc admin would act on first in list).
  static Future<String?> latestPendingDocumentId() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return null;
    final rows = await _client
        .from('chef_documents')
        .select('id')
        .eq('chef_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>? ?? const [];
    if (list.isEmpty) return null;
    final id = (list.first as Map)['id'];
    if (id == null) return null;
    final s = id.toString();
    return s.isEmpty ? null : s;
  }

  static Future<void> simulateApprove() async {
    final docId = await latestPendingDocumentId();
    if (docId == null) {
      throw Exception('No pending document to approve.');
    }
    await _client.rpc<void>(
      'apply_chef_document_review',
      params: {
        'p_document_id': docId,
        'p_status': 'approved',
        'p_rejection_reason': null,
      },
    );
  }

  static Future<void> simulateReject({required String reason}) async {
    final docId = await latestPendingDocumentId();
    if (docId == null) {
      throw Exception('No pending document to reject.');
    }
    final r = reason.trim();
    if (r.isEmpty) {
      throw Exception('Rejection reason is required.');
    }
    await _client.rpc<void>(
      'apply_chef_document_review',
      params: {
        'p_document_id': docId,
        'p_status': 'rejected',
        'p_rejection_reason': r,
      },
    );
  }
}
