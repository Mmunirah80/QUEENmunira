import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/supabase_error_message.dart';
import '../presentation/providers/admin_providers.dart';
import '../../cook/data/cook_required_document_types.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';

/// Lists approved cook documents that are past [expiry_date] (admin SELECT).
class AdminExpiredDocumentsScreen extends ConsumerWidget {
  const AdminExpiredDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Expired documents'),
        actions: const [AdminSignOutIconButton()],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(adminSupabaseDatasourceProvider).fetchExpiredDocumentsForAdmin(limit: 100),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading documents…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.hasError) {
            return Center(child: Text(userFriendlyErrorMessage(snap.error!)));
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.event_available_rounded,
              title: 'No expired approved documents',
              subtitle: 'When a cook’s approved document passes expiry, it will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminPanelTokens.cardRadius)),
                child: ListTile(
                  title: Text(CookRequiredDocumentTypes.displayLabelForRawDocumentType(
                    (r['document_type'] ?? '').toString(),
                  )),
                  subtitle: Text(
                    'Cook: ${(r['chef_id'] ?? '').toString()}\nExpires: ${r['expiry_date'] ?? '—'}',
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
