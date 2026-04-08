import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/domain/chat_conversation_scope.dart';

void main() {
  group('ChatConversationScope — customer', () {
    test('customer-chef inbox only for matching customer_id', () {
      expect(
        ChatConversationScope.customerChefInboxRow(
          row: {'customer_id': 'me', 'chef_id': 'c1', 'type': 'customer-chef'},
          sessionCustomerId: 'me',
        ),
        isTrue,
      );
      expect(
        ChatConversationScope.customerChefInboxRow(
          row: {'customer_id': 'other', 'chef_id': 'c1', 'type': 'customer-chef'},
          sessionCustomerId: 'me',
        ),
        isFalse,
      );
    });

    test('customer-chef excludes support lane', () {
      expect(
        ChatConversationScope.customerChefInboxRow(
          row: {'customer_id': 'me', 'type': 'customer-support'},
          sessionCustomerId: 'me',
        ),
        isFalse,
      );
    });

    test('customer-support lane', () {
      expect(
        ChatConversationScope.customerSupportInboxRow(
          row: {'customer_id': 'me', 'type': 'customer-support'},
          sessionCustomerId: 'me',
        ),
        isTrue,
      );
    });
  });
}
