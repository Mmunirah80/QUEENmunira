import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/chat_composer_policy.dart';

/// Chef chat: composer hidden when kitchen/account messaging is blocked.
void main() {
  group('ChatComposerPolicy — chef scenarios', () {
    test('normal chef chat → composer shown', () {
      expect(
        ChatComposerPolicy.showComposer(
          accountMessagingBlocked: false,
          chefKitchenSuspended: false,
        ),
        isTrue,
      );
    });

    test('account messaging blocked → composer hidden', () {
      expect(
        ChatComposerPolicy.showComposer(
          accountMessagingBlocked: true,
          chefKitchenSuspended: false,
        ),
        isFalse,
      );
    });

    test('chef kitchen suspended (moderation) → composer hidden', () {
      expect(
        ChatComposerPolicy.showComposer(
          accountMessagingBlocked: false,
          chefKitchenSuspended: true,
        ),
        isFalse,
      );
    });

    test('blocked account wins over other flags', () {
      expect(
        ChatComposerPolicy.showComposer(
          accountMessagingBlocked: true,
          chefKitchenSuspended: true,
        ),
        isFalse,
      );
    });
  });
}
