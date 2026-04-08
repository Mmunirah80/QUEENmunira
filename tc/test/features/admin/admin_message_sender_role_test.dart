import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/presentation/widgets/admin_design_system_widgets.dart';

/// Admin chat thread role resolution (order chat vs support lanes).
void main() {
  const admin = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const chef = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const customer = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

  group('resolveAdminMessageSenderRole', () {
    test('admin sender in customer-chef thread → admin', () {
      expect(
        resolveAdminMessageSenderRole(
          senderId: admin,
          adminId: admin,
          conversationType: 'customer-chef',
          customerId: customer,
          chefId: chef,
        ),
        AdminMessageSenderRole.admin,
      );
    });

    test('chef sender in customer-chef thread → cook', () {
      expect(
        resolveAdminMessageSenderRole(
          senderId: chef,
          adminId: admin,
          conversationType: 'customer-chef',
          customerId: customer,
          chefId: chef,
        ),
        AdminMessageSenderRole.cook,
      );
    });

    test('customer sender in customer-chef thread → customer', () {
      expect(
        resolveAdminMessageSenderRole(
          senderId: customer,
          adminId: admin,
          conversationType: 'customer-chef',
          customerId: customer,
          chefId: chef,
        ),
        AdminMessageSenderRole.customer,
      );
    });

    test('chef-admin lane: non-admin sender is cook', () {
      expect(
        resolveAdminMessageSenderRole(
          senderId: chef,
          adminId: admin,
          conversationType: 'chef-admin',
          customerId: '',
          chefId: chef,
        ),
        AdminMessageSenderRole.cook,
      );
    });

    test('customer-support lane: customer match → customer', () {
      expect(
        resolveAdminMessageSenderRole(
          senderId: customer,
          adminId: admin,
          conversationType: 'customer-support',
          customerId: customer,
          chefId: '',
        ),
        AdminMessageSenderRole.customer,
      );
    });

    test('empty sender id → unknown', () {
      expect(
        resolveAdminMessageSenderRole(
          senderId: '',
          adminId: admin,
          conversationType: 'customer-chef',
          customerId: customer,
          chefId: chef,
        ),
        AdminMessageSenderRole.unknown,
      );
    });
  });
}
