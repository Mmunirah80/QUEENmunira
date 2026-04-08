import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/presentation/chat_composer_policy.dart';

void main() {
  group('ChatComposerPolicy.showComposer', () {
    test('allows send when all gates false', () {
      expect(
        ChatComposerPolicy.showComposer(),
        isTrue,
      );
    });

    test('blocks when accountMessagingBlocked', () {
      expect(
        ChatComposerPolicy.showComposer(accountMessagingBlocked: true),
        isFalse,
      );
    });

    test('blocks when chefKitchenSuspended', () {
      expect(
        ChatComposerPolicy.showComposer(chefKitchenSuspended: true),
        isFalse,
      );
    });

    test('blocks when adminMonitorReadOnly (monitor mode)', () {
      expect(
        ChatComposerPolicy.showComposer(adminMonitorReadOnly: true),
        isFalse,
      );
    });

    test('blocked account wins over monitor flag combination', () {
      expect(
        ChatComposerPolicy.showComposer(
          accountMessagingBlocked: true,
          adminMonitorReadOnly: false,
        ),
        isFalse,
      );
    });
  });
}
