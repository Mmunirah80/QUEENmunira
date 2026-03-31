import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../presentation/providers/admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null || !user.isAdmin || user.isBlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.black45),
                const SizedBox(height: 16),
                Text(
                  user?.isBlocked == true
                      ? 'This account is blocked. Contact support.'
                      : 'Access denied. Sign in with an admin account.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go(RouteNames.login);
                  },
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final statsAsync = ref.watch(adminDashboardStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(adminDashboardStatsProvider);
              ref.read(adminPendingChefDocumentsNotifierProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  'Failed to load dashboard.\n$e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(adminDashboardStatsProvider);
                    ref.read(adminPendingChefDocumentsNotifierProvider.notifier).refresh();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          final cards = <_StatCardData>[
            _StatCardData(
              title: 'Orders Today',
              value: '${stats.ordersToday}',
              icon: Icons.receipt_long_outlined,
            ),
            _StatCardData(
              title: 'Revenue Today',
              value: 'SAR ${stats.revenueToday.toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
            ),
            _StatCardData(
              title: 'Active Chefs',
              value: '${stats.activeChefs}',
              icon: Icons.restaurant_menu_outlined,
            ),
            _StatCardData(
              title: 'Open Complaints',
              value: '${stats.openComplaints}',
              icon: Icons.support_agent_outlined,
            ),
          ];

          final allZero = stats.ordersToday == 0 &&
              stats.revenueToday == 0 &&
              stats.activeChefs == 0 &&
              stats.openComplaints == 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminDashboardStatsProvider);
              await ref.read(adminPendingChefDocumentsNotifierProvider.notifier).refresh();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (allZero)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, 8),
                      child: Text(
                        'No dashboard stats yet.\nAs activity grows, numbers will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final c = cards[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(c.icon, color: Theme.of(context).colorScheme.primary),
                                const Spacer(),
                                Text(
                                  c.value,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c.title,
                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: cards.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: const _PendingChefDocumentsCard(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PendingChefDocumentsCard extends ConsumerStatefulWidget {
  const _PendingChefDocumentsCard();

  @override
  ConsumerState<_PendingChefDocumentsCard> createState() =>
      _PendingChefDocumentsCardState();
}

class _PendingChefDocumentsCardState extends ConsumerState<_PendingChefDocumentsCard> {
  final Set<String> _busyIds = {};

  Future<void> _approve(String id) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await ref.read(adminSupabaseDatasourceProvider).setChefDocumentStatus(
            documentId: id,
            status: 'approved',
          );
      try {
        await ref.read(adminSupabaseDatasourceProvider).logAction(
              action: 'chef_document_approved',
              targetTable: 'chef_documents',
              targetId: id,
            );
      } catch (e, st) {
        debugPrint('[Admin] logAction after approve: $e\n$st');
      }
      await ref.read(adminPendingChefDocumentsNotifierProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document approved. Cook is updated if all required docs pass.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _reject(String id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ChefDocRejectReasonDialog(),
    );
    if (reason == null || reason.isEmpty) return;
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await ref.read(adminSupabaseDatasourceProvider).setChefDocumentStatus(
            documentId: id,
            status: 'rejected',
            rejectionReason: reason,
          );
      try {
        await ref.read(adminSupabaseDatasourceProvider).logAction(
              action: 'chef_document_rejected',
              targetTable: 'chef_documents',
              targetId: id,
              payload: {'reason': reason},
            );
      } catch (e, st) {
        debugPrint('[Admin] logAction after reject: $e\n$st');
      }
      await ref.read(adminPendingChefDocumentsNotifierProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document rejected. Cook notified when chat/notifications succeed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(adminPendingChefDocumentsNotifierProvider);
    final rows = st.rows;
    final notifier = ref.read(adminPendingChefDocumentsNotifierProvider.notifier);

    if (st.initialLoading && rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (st.error != null && rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load chef documents (check RLS for admin on chef_documents).\n'
                '${userFriendlyErrorMessage(st.error!)}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => notifier.refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No pending chef documents. Uploads from the cook app appear here with status pending.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    final titleCount = st.hasMore ? '${rows.length}+' : '${rows.length}';
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Chef documents pending review ($titleCount loaded)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          st.hasMore
              ? 'Showing the newest ${rows.length}; load more for additional pending rows.'
              : 'Approve or reject each row; older versions stay in the table for audit.',
        ),
        children: [
          if (st.error != null && rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                userFriendlyErrorMessage(st.error!),
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          ...rows.map((r) {
            final id = (r['id'] ?? '').toString();
            final cid = (r['chef_id'] ?? '').toString();
            final short = cid.length > 8 ? '${cid.substring(0, 8)}…' : cid;
            final kitchen = (r['_kitchen_name'] ?? '').toString().trim();
            final chefLabel = kitchen.isNotEmpty && kitchen != cid ? '$kitchen ($short)' : short;
            final busy = _busyIds.contains(id);
            return ListTile(
              dense: true,
              leading: const Icon(Icons.description_outlined),
              title: Text('${r['document_type'] ?? '?'} · $chefLabel'),
              subtitle: Text(
                'submitted: ${r['created_at'] ?? r['updated_at'] ?? '—'}'
                '${r['expiry_date'] != null ? ' · expires ${r['expiry_date']}' : ''}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Approve',
                    onPressed: busy || id.isEmpty ? null : () => _approve(id),
                    icon: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline, color: Colors.green),
                  ),
                  IconButton(
                    tooltip: 'Reject',
                    onPressed: busy || id.isEmpty ? null : () => _reject(id),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  ),
                ],
              ),
            );
          }),
          if (st.hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: st.loadingMore
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: () => notifier.loadMore(),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more'),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ChefDocRejectReasonDialog extends StatefulWidget {
  const _ChefDocRejectReasonDialog();

  @override
  State<_ChefDocRejectReasonDialog> createState() => _ChefDocRejectReasonDialogState();
}

class _ChefDocRejectReasonDialogState extends State<_ChefDocRejectReasonDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rejection reason'),
      content: TextField(
        controller: _reason,
        decoration: const InputDecoration(hintText: 'Reason for cook'),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = _reason.text.trim();
            if (t.isEmpty) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Enter a reason the cook will see in notifications and Support chat.')),
              );
              return;
            }
            Navigator.pop(context, t);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _StatCardData {
  final String title;
  final String value;
  final IconData icon;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
  });
}

