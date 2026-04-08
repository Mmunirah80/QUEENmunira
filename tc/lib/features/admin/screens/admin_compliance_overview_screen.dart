import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';

/// Admin ledger of automatic penalties from random inspections ([chef_violations]).
class AdminComplianceOverviewScreen extends ConsumerWidget {
  const AdminComplianceOverviewScreen({super.key});

  static String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat.yMMMd().add_jm().format(d.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminInspectionViolationsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: 20,
        title: const AdminAppBarTitle(
          title: 'Compliance & violations',
          subtitle: 'Inspection penalties ledger',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminInspectionViolationsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading violations…',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.gavel_outlined,
              title: 'No violation rows yet',
              subtitle: 'Countable inspection outcomes create entries here automatically.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              final kitchen = (r['_kitchen_name'] ?? r['chef_id'] ?? '—').toString();
              final action = (r['action_applied'] ?? '—').toString();
              final reason = (r['reason'] ?? '').toString();
              final idx = (r['violation_index'] as num?)?.toInt();
              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminPanelTokens.cardRadius)),
                child: ListTile(
                  title: Text(kitchen, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'Automatic action: $action\n'
                    'Outcome / reason: ${reason.isEmpty ? '—' : reason}\n'
                    'Violation #${idx ?? '—'} · ${_fmt(r['created_at']?.toString())}',
                    style: TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
