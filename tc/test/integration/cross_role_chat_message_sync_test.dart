import 'package:flutter_test/flutter_test.dart';

import 'support/cross_role_sync_stores.dart';

/// E.17–18: same conversation bucket — customer sends, chef unread; chef reads pattern via policy.
void main() {
  const conversationId = 'conv-1';
  const customerId = 'cust-1';
  const chefId = 'chef-1';

  group('ChatMessageSyncStore', () {
    test('customer sends → chef sees unread from peer', () {
      final store = ChatMessageSyncStore();
      store.append(conversationId: conversationId, senderId: customerId, isRead: false);
      expect(store.unreadForUser(conversationId: conversationId, selfUserId: chefId), 1);
    });

    test('chef replies → customer unread count from chef messages', () {
      final store = ChatMessageSyncStore();
      store.append(conversationId: conversationId, senderId: customerId, isRead: true);
      store.append(conversationId: conversationId, senderId: chefId, isRead: false);
      expect(store.unreadForUser(conversationId: conversationId, selfUserId: customerId), 1);
    });

    test('all read → zero unread for both perspectives', () {
      final store = ChatMessageSyncStore();
      store.append(conversationId: conversationId, senderId: customerId, isRead: true);
      store.append(conversationId: conversationId, senderId: chefId, isRead: true);
      expect(store.unreadForUser(conversationId: conversationId, selfUserId: chefId), 0);
      expect(store.unreadForUser(conversationId: conversationId, selfUserId: customerId), 0);
    });
  });
}
