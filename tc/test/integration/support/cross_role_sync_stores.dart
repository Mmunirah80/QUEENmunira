import 'package:naham_cook_app/features/chat/domain/chat_unread_policy.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/reels/domain/reel_public_feed_visibility.dart';

/// In-memory chef profile row shared by "chef session" and "customer browse" tests.
class ChefProfileSyncStore {
  ChefProfileSyncStore(Map<String, dynamic> initialRow) : row = Map<String, dynamic>.from(initialRow);

  Map<String, dynamic> row;

  ChefDocModel get doc => ChefDocModel.fromSupabase(row);

  void patch(Map<String, dynamic> updates) {
    row.addAll(updates);
  }
}

/// Chef document rows + admin mutations (same logical DB as product rules).
class DocumentSyncStore {
  DocumentSyncStore();

  final Map<String, Map<String, Map<String, dynamic>>> _byChef = {};

  void seedChef(String chefId, List<Map<String, dynamic>> rows) {
    final m = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final t = (r['document_type'] ?? '').toString();
      m[t] = Map<String, dynamic>.from(r);
    }
    _byChef[chefId] = m;
  }

  void adminSetDocument({
    required String chefId,
    required String documentType,
    required String status,
    String? rejectionReason,
  }) {
    final chef = _byChef[chefId];
    if (chef == null) throw StateError('unknown chef');
    final row = chef[documentType];
    if (row == null) throw StateError('unknown doc type');
    row['status'] = status;
    if (rejectionReason != null) {
      row['rejection_reason'] = rejectionReason;
    } else {
      row.remove('rejection_reason');
    }
  }

  List<Map<String, dynamic>> chefRowsList(String chefId) {
    final chef = _byChef[chefId];
    if (chef == null) return const [];
    return chef.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> adminPendingQueue() {
    final out = <Map<String, dynamic>>[];
    for (final e in _byChef.entries) {
      for (final r in e.value.values) {
        final st = (r['status'] ?? '').toString().toLowerCase();
        if (st == 'pending_review' || st == 'pending') {
          out.add(Map<String, dynamic>.from(r)..['_chef_id'] = e.key);
        }
      }
    }
    return out;
  }
}

/// Reel rows visible to customer feed vs chef "my reels" list.
class ReelModerationSyncStore {
  ReelModerationSyncStore(List<Map<String, dynamic>> initial) {
    for (final r in initial) {
      reels.add(Map<String, dynamic>.from(r));
    }
  }

  final List<Map<String, dynamic>> reels = [];

  void adminSoftDelete(String reelId) {
    final i = reels.indexWhere((r) => (r['id'] ?? '').toString() == reelId);
    if (i < 0) return;
    reels[i]['deleted_at'] = DateTime.utc(2026, 1, 1).toIso8601String();
  }

  void adminHide(String reelId) {
    final i = reels.indexWhere((r) => (r['id'] ?? '').toString() == reelId);
    if (i < 0) return;
    reels[i]['is_hidden'] = true;
  }

  List<Map<String, dynamic>> customerPublicFeedRows() {
    return reels.where(isReelRowPublicFeedVisible).toList();
  }

  Map<String, dynamic>? chefRowById(String chefId, String reelId) {
    try {
      return reels.firstWhere(
        (r) => (r['chef_id'] ?? '').toString() == chefId && (r['id'] ?? '').toString() == reelId,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Conversation message bucket for unread / last-message style checks.
class ChatMessageSyncStore {
  ChatMessageSyncStore();

  final Map<String, List<Map<String, dynamic>>> _byConversation = {};

  void append({
    required String conversationId,
    required String senderId,
    bool isRead = false,
    String content = 'hi',
  }) {
    _byConversation.putIfAbsent(conversationId, () => []).add({
      'sender_id': senderId,
      'is_read': isRead,
      'content': content,
    });
  }

  List<Map<String, dynamic>> recentBucket(String conversationId) {
    return List<Map<String, dynamic>>.from(_byConversation[conversationId] ?? const []);
  }

  int unreadForUser({
    required String conversationId,
    required String selfUserId,
  }) {
    return ChatUnreadPolicy.unreadFromRecentBucket(
      recentBucket(conversationId),
      selfUserId: selfUserId,
    );
  }
}
