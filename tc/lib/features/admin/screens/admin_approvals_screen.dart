import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_pending_cook_documents_panel.dart';
import 'admin_inspections_screen.dart';

/// Cook applications and document review (primary flow). Live kitchen check is optional.
class AdminApprovalsScreen extends ConsumerWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cook Applications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Review documents. Approve or reject.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const AdminPendingCookDocumentsPanel(),
          const SizedBox(height: 24),
          Text(
            'More',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const AdminInspectionsScreen()),
              );
            },
            icon: const Icon(Icons.videocam_outlined, size: 20),
            label: const Text('View kitchen check'),
          ),
        ],
      ),
    );
  }
}
