/// Central limits for chat queries and UI (memory / performance).
abstract final class ChatLimits {
  /// Max messages loaded per thread in REST and capped in realtime maps.
  static const int maxMessagesPerThread = 500;

  /// Recent messages scanned per conversation when batching unread counts.
  static const int recentMessagesForUnread = 50;

  /// Upper bound on rows fetched in one batch for cook inbox preview.
  static const int maxInboxBatchMessageRows = 5000;
}
