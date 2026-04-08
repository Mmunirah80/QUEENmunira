import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/domain/chat_conversation_scope.dart';

void main() {
  group('ChatConversationScope', () {
    test('customer-chef inbox excludes other chefs threads', () {
      expect(
        ChatConversationScope.chefCustomerChefInboxRow(
          row: {'chef_id': 'me', 'type': 'customer-chef'},
          sessionChefId: 'me',
        ),
        isTrue,
      );
      expect(
        ChatConversationScope.chefCustomerChefInboxRow(
          row: {'chef_id': 'other', 'type': 'customer-chef'},
          sessionChefId: 'me',
        ),
        isFalse,
      );
    });

    test('customer-chef inbox excludes other conversation types', () {
      expect(
        ChatConversationScope.chefCustomerChefInboxRow(
          row: {'chef_id': 'me', 'type': 'chef-admin'},
          sessionChefId: 'me',
        ),
        isFalse,
      );
    });

    test('chef-admin support lane only for matching type', () {
      expect(
        ChatConversationScope.chefAdminSupportInboxRow(
          row: {'chef_id': 'me', 'type': 'chef-admin'},
          sessionChefId: 'me',
        ),
        isTrue,
      );
      expect(
        ChatConversationScope.chefAdminSupportInboxRow(
          row: {'chef_id': 'me', 'type': 'customer-chef'},
          sessionChefId: 'me',
        ),
        isFalse,
      );
    });
  });
}
