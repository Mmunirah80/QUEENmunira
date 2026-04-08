import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/screens/admin_monitor_chats_screen.dart';
import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/chat/domain/entities/chat_entity.dart';
import 'package:naham_cook_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/chat_monitor_banner.dart';
import 'package:naham_cook_app/features/chat/presentation/widgets/naham_chat_input_bar.dart';

/// Admin [AdminSupportConversationScreen] in monitor mode: read-only UI contract.
void main() {
  const chatId = '00000000-0000-4000-8000-000000000001';
  const adminUid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const chefUid = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const custUid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

  testWidgets('monitorOnly: monitoring banner visible, no NahamChatInputBar, no TextField', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminChatSessionUserIdProvider.overrideWith((ref) => adminUid),
          messagesStreamProvider.overrideWith((ref, id) {
            return Stream<List<MessageEntity>>.value([
              MessageEntity(
                id: 'm1',
                chatId: id,
                senderId: custUid,
                content: 'Hello from customer',
                timestamp: DateTime.utc(2025, 6, 1, 12, 0),
              ),
            ]);
          }),
          adminConversationMetaProvider.overrideWith((ref, id) async {
            return <String, dynamic>{
              'type': 'customer-chef',
              'customer_id': custUid,
              'chef_id': chefUid,
              '_header_customer': 'Alice',
              '_header_cook': 'Um Noura Kitchen',
            };
          }),
        ],
        child: const MaterialApp(
          home: AdminSupportConversationScreen(
            chatId: chatId,
            title: 'Test',
            conversationType: 'customer-chef',
            monitorOnly: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ChatMonitorBanner), findsOneWidget);
    expect(find.text('Monitoring conversation'), findsOneWidget);
    expect(find.byType(NahamChatInputBar), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Hello from customer'), findsOneWidget);
  });

  testWidgets('monitorOnly false: input bar present', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminChatSessionUserIdProvider.overrideWith((ref) => adminUid),
          messagesStreamProvider.overrideWith((ref, id) {
            return Stream<List<MessageEntity>>.value(const []);
          }),
          adminConversationMetaProvider.overrideWith((ref, id) async {
            return <String, dynamic>{
              'type': 'customer-support',
              'customer_id': custUid,
              'chef_id': '',
            };
          }),
        ],
        child: const MaterialApp(
          home: AdminSupportConversationScreen(
            chatId: chatId,
            title: 'Support',
            conversationType: 'customer-support',
            monitorOnly: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NahamChatInputBar), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ChatMonitorBanner), findsNothing);
  });
}
