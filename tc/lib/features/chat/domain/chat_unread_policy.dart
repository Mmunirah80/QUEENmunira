/// Unread count from recent message rows (newest-first buckets per conversation).
abstract final class ChatUnreadPolicy {
  ChatUnreadPolicy._();

  /// Counts messages not sent by [selfUserId] that are still unread.
  static int unreadFromRecentBucket(
    Iterable<Map<String, dynamic>> recentMessagesNewestFirst, {
    required String selfUserId,
  }) {
    var n = 0;
    for (final m in recentMessagesNewestFirst) {
      final senderId = (m['sender_id'] ?? '').toString();
      final isRead = m['is_read'] as bool? ?? false;
      if (senderId != selfUserId && !isRead) n++;
    }
    return n;
  }
}
