import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/presentation/chat_admin_message_labels.dart';
import 'package:naham_cook_app/features/admin/presentation/widgets/admin_design_system_widgets.dart';

/// Role label strings above admin conversation bubbles.
void main() {
  const admin = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const chef = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const customer = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

  group('adminChatSenderDisplayName', () {
    test('admin id → Admin', () {
      expect(
        adminChatSenderDisplayName(
          senderId: admin,
          adminId: admin,
          customerId: customer,
          chefId: chef,
          headerCustomer: 'Alice',
          headerCook: 'Kitchen A',
        ),
        'Admin',
      );
    });

    test('customer id uses header name when set', () {
      expect(
        adminChatSenderDisplayName(
          senderId: customer,
          adminId: admin,
          customerId: customer,
          chefId: chef,
          headerCustomer: 'Alice',
          headerCook: 'Kitchen A',
        ),
        'Alice',
      );
    });

    test('customer id falls back to Customer when header empty', () {
      expect(
        adminChatSenderDisplayName(
          senderId: customer,
          adminId: admin,
          customerId: customer,
          chefId: chef,
          headerCustomer: '',
          headerCook: '',
        ),
        'Customer',
      );
    });

    test('chef id uses kitchen header when set', () {
      expect(
        adminChatSenderDisplayName(
          senderId: chef,
          adminId: admin,
          customerId: customer,
          chefId: chef,
          headerCustomer: '',
          headerCook: 'Um Noura Kitchen',
        ),
        'Um Noura Kitchen',
      );
    });

    test('chef id falls back to Kitchen when header empty', () {
      expect(
        adminChatSenderDisplayName(
          senderId: chef,
          adminId: admin,
          customerId: customer,
          chefId: chef,
          headerCustomer: '',
          headerCook: '',
        ),
        'Kitchen',
      );
    });
  });

  group('adminChatMessageRoleLabel', () {
    test('admin role in support lane → Support', () {
      expect(
        adminChatMessageRoleLabel(
          role: AdminMessageSenderRole.admin,
          senderDisplay: 'Admin',
          supportLane: true,
        ),
        'Support',
      );
    });

    test('admin role in order chat → Admin', () {
      expect(
        adminChatMessageRoleLabel(
          role: AdminMessageSenderRole.admin,
          senderDisplay: 'Admin',
          supportLane: false,
        ),
        'Admin',
      );
    });

    test('customer role uses senderDisplay', () {
      expect(
        adminChatMessageRoleLabel(
          role: AdminMessageSenderRole.customer,
          senderDisplay: 'Alice',
          supportLane: false,
        ),
        'Alice',
      );
    });

    test('long kitchen name preserved', () {
      const longName = 'Um Noura Kitchen — Downtown Branch Special';
      expect(
        adminChatMessageRoleLabel(
          role: AdminMessageSenderRole.cook,
          senderDisplay: longName,
          supportLane: false,
        ),
        longName,
      );
    });

    test('empty senderDisplay falls back to role.label', () {
      expect(
        adminChatMessageRoleLabel(
          role: AdminMessageSenderRole.unknown,
          senderDisplay: '   ',
          supportLane: false,
        ),
        'Participant',
      );
    });
  });
}
