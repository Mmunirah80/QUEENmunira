import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:naham_cook_app/core/constants/route_names.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/features/admin/domain/admin_application_review_logic.dart';
import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/admin/screens/admin_orders_screen.dart';
import 'package:naham_cook_app/features/admin/services/admin_actions_service.dart';
import 'package:naham_cook_app/features/admin/presentation/widgets/admin_design_system_widgets.dart';
import 'package:naham_cook_app/features/admin/presentation/widgets/admin_pending_cook_documents_panel.dart';

/// Dashboard operational queues: real Supabase-backed rows with safe inline actions.
class AdminDashboardOperationalSection extends ConsumerStatefulWidget {
  const AdminDashboardOperationalSection({super.key});

  @override
  ConsumerState<AdminDashboardOperationalSection> createState() =>
      _AdminDashboardOperationalSectionState();
}

class _AdminDashboardOperationalSectionState extends ConsumerState<AdminDashboardOperationalSection> {
  final Set<String> _busyDocIds = <String>{};
  final Set<String> _busyReelIds = <String>{};

  Future<void> _approveDoc(String documentId, String chefId) async {
    if (_busyDocIds.contains(documentId) || chefId.isEmpty) return;
    setState(() => _busyDocIds.add(documentId));
    try {
      await ref.read(adminActionsServiceProvider).approveCookDocument(
            context,
            documentId: documentId,
            chefId: chefId,
          );
    } finally {
      if (mounted) setState(() => _busyDocIds.remove(documentId));
    }
  }

  Future<void> _rejectDoc(String documentId, String chefId) async {
    if (_busyDocIds.contains(documentId) || chefId.isEmpty) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const AdminCookDocReasonDialog(title: 'Rejection reason', confirmLabel: 'Reject'),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _busyDocIds.add(documentId));
    try {
      await ref.read(adminActionsServiceProvider).submitCookDocumentRejection(
            context,
            documentId: documentId,
            chefId: chefId,
            reason: reason,
          );
    } finally {
      if (mounted) setState(() => _busyDocIds.remove(documentId));
    }
  }

  Future<void> _deleteReel(String reelId, String chefId) async {
    if (_busyReelIds.contains(reelId)) return;
    setState(() => _busyReelIds.add(reelId));
    try {
      await ref.read(adminActionsServiceProvider).deleteReel(
            context,
            reelId: reelId,
            chefId: chefId.isEmpty ? null : chefId,
          );
    } finally {
      if (mounted) setState(() => _busyReelIds.remove(reelId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = ref.watch(adminPendingCookDocumentsNotifierProvider);
    final reelsAsync = ref.watch(adminDashboardReportedReelsProvider);
    final ordersAsync = ref.watch(adminDashboardRecentOrdersSampleProvider);
    final ticketsAsync = ref.watch(adminDashboardSupportTicketsProvider);

    final appSlice = pending.groups.take(6).toList();
    final orderRows = ordersAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final delayed = orderRows
        .where((r) => AdminOrdersScreen.stuckOrderMatches(r, AdminOrdersStuckSubtype.any))
        .take(6)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            title: 'Operational queues',
            subtitle: 'Live data from documents, reels, orders, and support tickets.',
          ),
          if (pending.initialLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (appSlice.isEmpty)
            const SizedBox.shrink()
          else ...[
            Text('Recent cook applications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final g in appSlice)
              _docApplicationRow(context, g, scheme),
            const SizedBox(height: 16),
          ],
          Text('Recent reported reels', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          reelsAsync.when(
            loading: () => const Card(
              child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(userFriendlyErrorMessage(e)),
              ),
            ),
            data: (reels) {
              if (reels.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No reported reels in the current sample (needs reel_reports + admin SELECT).',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in reels)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          (r['_kitchen_name'] ?? r['chef_id'] ?? 'Reel').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Reports: ${(r['report_count'] as num?)?.toInt() ?? 0} · ${(r['created_at'] ?? '').toString()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Open Reels',
                              icon: const Icon(Icons.open_in_new_rounded),
                              onPressed: () {
                                ref.read(adminReelsModerationFilterProvider.notifier).state =
                                    AdminReelsModerationFilter.reported;
                                ref.read(adminBottomNavIndexProvider.notifier).state = 4;
                              },
                            ),
                            IconButton(
                              tooltip: 'Remove reel',
                              icon: _busyReelIds.contains((r['id'] ?? '').toString())
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.delete_outline_rounded),
                              onPressed: _busyReelIds.contains((r['id'] ?? '').toString())
                                  ? null
                                  : () => _deleteReel(
                                        (r['id'] ?? '').toString(),
                                        (r['chef_id'] ?? '').toString(),
                                      ),
                            ),
                          ],
                        ),
                        onTap: () {
                          final cid = (r['chef_id'] ?? '').toString();
                          if (cid.isEmpty) return;
                          context.push(RouteNames.adminUserDetail(cid));
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Recent delayed orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ordersAsync.when(
            loading: () => const Card(
              child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(userFriendlyErrorMessage(e)),
              ),
            ),
            data: (rows) {
              if (delayed.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      rows.isEmpty ? 'No orders loaded.' : 'No delayed orders (>2h in active status) in this sample.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in delayed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AdminOrdersScreen.orderMonitoringCard(
                        context,
                        r: r,
                        onTap: () {
                          final id = (r['id'] ?? '').toString();
                          if (id.isEmpty) return;
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminOrderDetailScreen(orderId: id),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Recent flagged conversations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ticketsAsync.when(
            loading: () => const Card(
              child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(userFriendlyErrorMessage(e)),
              ),
            ),
            data: (pack) {
              if (!pack.backendAvailable) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Backend-dependent: expose a support or moderation table (e.g. support_tickets) with admin RLS, '
                      'or link flagged chats from your schema. Until then, use Chat Monitoring manually.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35),
                    ),
                  ),
                );
              }
              if (pack.rows.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No open tickets in support_tickets.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final t in pack.rows)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          (t['subject'] ?? 'Ticket').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${(t['status'] ?? '').toString()} · ${(t['created_at'] ?? '').toString()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.forum_outlined),
                        onTap: () {
                          ref.read(adminBottomNavIndexProvider.notifier).state = 3;
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _docApplicationRow(BuildContext context, AdminPendingApplicationGroup g, ColorScheme scheme) {
    final latestByType = latestRequiredDocumentRowsBySlot(g.documents);
    final pendingForAction =
        latestByType.values.where((d) => documentRowNeedsAdminDecision(d)).toList();
    final doc = pendingForAction.isNotEmpty ? pendingForAction.first : null;
    final docId = (doc?['id'] ?? '').toString();
    final chefId = g.chefId;
    final busy = _busyDocIds.contains(docId);
    final subtitle = pendingForAction.isEmpty
        ? 'No pending documents in queue'
        : '${pendingForAction.length} document(s) awaiting review';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(g.kitchenName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: busy || docId.isEmpty || chefId.isEmpty ? null : () => _approveDoc(docId, chefId),
              child: const Text('Approve'),
            ),
            TextButton(
              onPressed: busy || docId.isEmpty || chefId.isEmpty ? null : () => _rejectDoc(docId, chefId),
              child: Text('Reject', style: TextStyle(color: scheme.error)),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: chefId.isEmpty
            ? null
            : () {
                ref.read(adminInspectionTabProvider.notifier).state = 0;
                ref.read(adminUsersHubTabProvider.notifier).state = 1;
                ref.read(adminBottomNavIndexProvider.notifier).state = 1;
                context.push(RouteNames.adminUserDetail(chefId));
              },
      ),
    );
  }
}
