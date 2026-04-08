import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validation/naham_validators.dart';
import '../../../features/auth/data/models/user_model.dart';
import '../data/datasources/admin_firebase_datasource.dart';

// ─── Providers ──────────────────────────────────────────────────────────────

final _adminDataSourceProvider = Provider<AdminFirebaseDataSource>(
  (_) => AdminFirebaseDataSource(),
);

final pendingChefsProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(_adminDataSourceProvider).watchPendingChefs();
});

// ─── Admin Panel ─────────────────────────────────────────────────────────────

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Pending cooks')],
          ),
        ),
        body: const TabBarView(
          children: [_PendingChefsTab()],
        ),
      ),
    );
  }
}

// ─── Pending cooks (Firebase legacy) ─────────────────────────────────────────

class _PendingChefsTab extends ConsumerWidget {
  const _PendingChefsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingChefsProvider);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (chefs) {
        if (chefs.isEmpty) {
          return const Center(child: Text('No pending cooks'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chefs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _ChefCard(chef: chefs[i]),
        );
      },
    );
  }
}

// ─── Pending cook card ───────────────────────────────────────────────────────

class _ChefCard extends ConsumerWidget {
  final UserModel chef;
  const _ChefCard({required this.chef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.read(_adminDataSourceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chef.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 4),
            Text(chef.email,
                style: Theme.of(context).textTheme.bodySmall),
            if (chef.phone != null)
              Text(chef.phone!,
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _reject(context, ds),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await ds.approveChef(chef.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('${chef.name} approved')),
                        );
                      }
                    },
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, AdminFirebaseDataSource ds) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject cook'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText: 'e.g. Missing documents',
            ),
            maxLines: 3,
            validator: NahamValidators.reasonField,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ds.rejectChef(chef.id, reason: reasonCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${chef.name} rejected')),
        );
      }
    }
    reasonCtrl.dispose();
  }
}
