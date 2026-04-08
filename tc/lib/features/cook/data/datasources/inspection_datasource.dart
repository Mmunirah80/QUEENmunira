import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';

final inspectionDataSourceProvider = Provider<InspectionDataSource>((ref) => InspectionDataSource());

/// Supabase-backed random inspection calls for the chef app.
class InspectionDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;

  /// Latest relevant row: active pending/accepted call, or newest unseen completed result.
  Stream<Map<String, dynamic>?> watchCurrentRequest(String chefId) {
    if (chefId.isEmpty) return const Stream<Map<String, dynamic>?>.empty();
    return _sb.from('inspection_calls').stream(primaryKey: ['id']).eq('chef_id', chefId).map((rows) {
      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) {
          final ta = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });

      Map<String, dynamic>? pending;
      Map<String, dynamic>? accepted;
      Map<String, dynamic>? unseenCompleted;
      for (final r in list) {
        final st = (r['status'] ?? '').toString();
        if (st == 'pending') {
          pending ??= r;
        } else if (st == 'accepted') {
          accepted ??= r;
        } else if (st == 'completed' && r['chef_result_seen'] != true) {
          unseenCompleted ??= r;
        }
      }
      if (pending != null) return _toUiMap(pending);
      if (accepted != null) return _toUiMap(accepted);
      if (unseenCompleted != null) return _toUiMap(unseenCompleted);
      return null;
    });
  }

  Future<void> acceptRequest(String chefId) async {
    final requestId = await _latestPendingRequestId(chefId);
    if (requestId == null) return;
    await _sb.rpc<void>(
      'chef_respond_inspection_call',
      params: {
        'p_call_id': requestId,
        'p_response': 'accepted',
      },
    );
  }

  Future<void> rejectRequest(String chefId) async {
    final requestId = await _latestPendingRequestId(chefId);
    if (requestId == null) return;
    await _sb.rpc<void>(
      'chef_respond_inspection_call',
      params: {
        'p_call_id': requestId,
        'p_response': 'declined',
      },
    );
  }

  Future<void> missRequest(String chefId) async {
    final requestId = await _latestPendingRequestId(chefId);
    if (requestId == null) return;
    await _sb.rpc<void>(
      'chef_respond_inspection_call',
      params: {
        'p_call_id': requestId,
        'p_response': 'missed',
      },
    );
  }

  /// Do not use for production — server should finalize. Kept for legacy callers.
  Future<void> clearCurrentRequest(String chefId) async {
    debugPrint('[Inspection] clearCurrentRequest is deprecated');
  }

  Future<void> markResultSeen(String callId) async {
    if (callId.isEmpty) return;
    await _sb.from('inspection_calls').update({'chef_result_seen': true}).eq('id', callId);
  }

  Future<String?> _latestPendingRequestId(String chefId) async {
    if (chefId.isEmpty) return null;
    final row = await _sb
        .from('inspection_calls')
        .select('id')
        .eq('chef_id', chefId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final id = (row?['id'] ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }

  Future<List<Map<String, dynamic>>> fetchInspectionHistoryForChef({
    required String chefId,
    int limit = 15,
  }) async {
    if (chefId.isEmpty || limit <= 0) return const [];
    try {
      final rows = await _sb
          .from('inspection_calls')
          .select(
            'id,status,outcome,result_action,counted_as_violation,violation_reason,result_note,created_at,finalized_at',
          )
          .eq('chef_id', chefId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('[Inspection] history: $e\n$st');
      return const [];
    }
  }

  Map<String, dynamic> _toUiMap(Map<String, dynamic> row) {
    return <String, dynamic>{
      'id': row['id'],
      'channelName': row['channel_name'],
      'status': row['status'],
      'resultAction': row['result_action'],
      'outcome': row['outcome'],
      'violationReason': row['violation_reason'],
      'resultNote': row['result_note'],
      'chefResultSeen': row['chef_result_seen'] == true,
    };
  }
}
