import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/loading_widget.dart';
import '../presentation/providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chefNotificationsProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(fontSize: 14, color: AppDesignSystem.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = items[index];
              final bgColor = n.isRead ? Colors.white : AppDesignSystem.cardWhite.withOpacity(0.9);
              final borderColor = n.isRead ? AppDesignSystem.surfaceLight : AppDesignSystem.primaryLight;
              final time = DateFormat('MMM d, h:mm a').format(n.createdAt.toLocal());
              return InkWell(
                onTap: () async {
                  final client = Supabase.instance.client;
                  if (!n.isRead && n.id.isNotEmpty) {
                    await client.from('notifications').update({'is_read': true}).eq('id', n.id);
                    ref.invalidate(chefNotificationsProvider);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppDesignSystem.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: AppDesignSystem.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Unread',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppDesignSystem.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (e, _) => Center(
          child: Text(
            userFriendlyErrorMessage(e),
            style: const TextStyle(color: AppDesignSystem.errorRed),
          ),
        ),
      ),
    );
  }
}

