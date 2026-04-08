import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/chat/domain/chat_unread_policy.dart';

void main() {
  group('ChatUnreadPolicy.unreadFromRecentBucket', () {
    const selfId = 'chef-1';

    test('counts unread messages from peer only', () {
      final rows = [
        {'sender_id': 'cust', 'is_read': false},
        {'sender_id': 'cust', 'is_read': true},
        {'sender_id': selfId, 'is_read': false},
      ];
      expect(
        ChatUnreadPolicy.unreadFromRecentBucket(rows, selfUserId: selfId),
        1,
      );
    });

    test('all read from peer => zero', () {
      final rows = [
        {'sender_id': 'cust', 'is_read': true},
        {'sender_id': 'cust', 'is_read': true},
      ];
      expect(
        ChatUnreadPolicy.unreadFromRecentBucket(rows, selfUserId: selfId),
        0,
      );
    });

    test('missing is_read treated as unread', () {
      final rows = [
        {'sender_id': 'cust'},
      ];
      expect(
        ChatUnreadPolicy.unreadFromRecentBucket(rows, selfUserId: selfId),
        1,
      );
    });
  });
}
