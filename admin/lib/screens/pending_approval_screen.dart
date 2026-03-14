import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/naham_screen_header.dart';
import '../core/widgets/naham_empty_screens.dart';
import '../core/widgets/snackbar_helper.dart';
import '../data/models/user_model.dart';
import '../providers/admin_providers.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingChefsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const NahamScreenHeader(title: 'الموافقات المعلقة'),
          Expanded(
            child: async.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: NahamEmptyStateContent(
                      title: 'لا توجد طلبات معلقة',
                      subtitle: 'جميع طلبات الطباخين تمت مراجعتها.',
                      buttonLabel: 'تحديث',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppDesignSystem.space16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _PendingTile(
                    user: list[i],
                    onApprove: () => _approve(ref, context, list[i]),
                    onReject: () => _reject(ref, context, list[i]),
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, st) => ErrorStateContent(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(WidgetRef ref, BuildContext context, UserModel user) async {
    try {
      await ref.read(adminFirebaseDataSourceProvider).approveChef(user.id);
      if (context.mounted) SnackbarHelper.success(context, 'تمت الموافقة على ${user.name}');
    } catch (e) {
      if (context.mounted) SnackbarHelper.error(context, e.toString());
    }
  }

  void _reject(WidgetRef ref, BuildContext context, UserModel user) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض',
            hintText: 'أدخل سبب الرفض',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(adminFirebaseDataSourceProvider).rejectChef(user.id, reason: reason);
                if (context.mounted) SnackbarHelper.success(context, 'تم رفض الطلب');
              } catch (e) {
                if (context.mounted) SnackbarHelper.error(context, e.toString());
              }
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingTile({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.space12),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: NahamTheme.primary.withOpacity(0.2),
                  child: Text(
                    (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                    style: const TextStyle(color: NahamTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppDesignSystem.errorRed),
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(backgroundColor: AppDesignSystem.successGreen),
                    child: const Text('موافقة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
