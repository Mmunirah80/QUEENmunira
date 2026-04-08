/// Central rules for whether the chat composer (input + send) may appear.
///
/// Keep in sync with `_send` / insert guards on each conversation screen.
abstract final class ChatComposerPolicy {
  ChatComposerPolicy._();

  /// When false, hide [NahamChatInputBar] entirely and do not send messages.
  static bool showComposer({
    bool accountMessagingBlocked = false,
    bool chefKitchenSuspended = false,
    bool adminMonitorReadOnly = false,
  }) {
    if (accountMessagingBlocked) return false;
    if (chefKitchenSuspended) return false;
    if (adminMonitorReadOnly) return false;
    return true;
  }
}
