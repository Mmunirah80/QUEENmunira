import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:naham_cook_app/core/supabase/supabase_config.dart';
import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/orders/presentation/orders_failure.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';

import 'package:naham_cook_app/features/admin/presentation/widgets/admin_design_system_widgets.dart';
import 'admin_monitor_chats_screen.dart';

/// Admin: browse all customer/cook orders and open read-only detail (RLS admin SELECT).
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();

  static String _formatMoney(dynamic v) {
    if (v is num) return v.toDouble().toStringAsFixed(2);
    if (v is String) return double.tryParse(v)?.toStringAsFixed(2) ?? v;
    return '0.00';
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  /// Maps DB `orders.status` (+ optional `cancel_reason`) to a short monitoring label.
  /// Customer-facing cancellation copy is unified to two outcomes (see [OrderDbStatus.customerFacingLabel]).
  static String statusLabel(String raw, {String? cancelReason}) {
    final r = raw.trim();
    if (r == 'paid_waiting_acceptance') return 'Paid · awaiting Cook';
    final d = OrderDbStatus.domainFromDb(r);
    return switch (d) {
      OrderStatus.pending => 'Pending',
      OrderStatus.accepted => 'Accepted',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready for pickup',
      OrderStatus.completed => 'Completed',
      OrderStatus.rejected => OrderDbStatus.customerFacingLabel(
          r,
          cancelReason: cancelReason,
          orderStatusFallback: OrderStatus.cancelled,
        ),
      OrderStatus.cancelled => OrderDbStatus.customerFacingLabel(
          r,
          cancelReason: cancelReason,
          orderStatusFallback: OrderStatus.cancelled,
        ),
    };
  }

  static bool _matchesOrderTab(String statusRaw, int tabIndex) {
    final s = statusRaw.trim();
    if (tabIndex == 0) return true;
    if (tabIndex == 1) return OrderDbStatus.isInKitchenDbStatus(s);
    if (tabIndex == 2) return s == 'completed';
    if (tabIndex == 3) {
      return OrderDbStatus.cancelled.contains(s) || s == 'rejected';
    }
    return true;
  }

  /// Matches dashboard alert “stuck” definition (active > 2h without update).
  static bool _isStuckOrder(Map<String, dynamic> r, AdminOrdersStuckSubtype subtype) {
    const active = {
      'paid_waiting_acceptance',
      'pending',
      'accepted',
      'preparing',
      'ready',
    };
    final s = (r['status'] ?? '').toString().trim();
    if (!active.contains(s)) return false;
    final u = DateTime.tryParse((r['updated_at'] ?? '').toString());
    if (u == null) return false;
    if (DateTime.now().difference(u) <= const Duration(hours: 2)) return false;
    return switch (subtype) {
      AdminOrdersStuckSubtype.any => true,
      AdminOrdersStuckSubtype.acceptedLong => s == 'accepted',
      AdminOrdersStuckSubtype.preparingLong => OrderDbStatus.preparing.contains(s),
      AdminOrdersStuckSubtype.readyLong => s == 'ready',
    };
  }

  /// Public alias for dashboard / widgets outside this library.
  static bool stuckOrderMatches(Map<String, dynamic> r, AdminOrdersStuckSubtype subtype) =>
      _isStuckOrder(r, subtype);

  /// Compact row: order id, last message (chat or note), status, time.
  static AdminStatusVariant _statusVariantForOrder(String statusRaw) {
    final r = statusRaw.trim();
    if (OrderDbStatus.cancelled.contains(r) || r == 'rejected') {
      return AdminStatusVariant.blocked;
    }
    if (r == 'completed') return AdminStatusVariant.active;
    if (OrderDbStatus.pending.contains(r) || r == 'paid_waiting_acceptance') {
      return AdminStatusVariant.pending;
    }
    return AdminStatusVariant.neutral;
  }

  static Widget orderMonitoringCard(
    BuildContext context, {
    required Map<String, dynamic> r,
    VoidCallback? onTap,
  }) {
    final id = (r['id'] ?? '').toString();
    final statusRaw = (r['status'] ?? '').toString();
    final status = statusLabel(
      statusRaw,
      cancelReason: r['cancel_reason']?.toString(),
    );
    final previewRaw = (r['_last_message_preview'] ?? r['notes'] ?? '').toString().trim();
    final lastLine = previewRaw.isEmpty
        ? '—'
        : (previewRaw.length > 72 ? '${previewRaw.substring(0, 72)}…' : previewRaw);
    final t = DateTime.tryParse((r['updated_at'] ?? r['created_at'] ?? '').toString());
    final timeStr = t != null ? DateFormat.MMMd().add_jm().format(t.toLocal()) : '—';
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AdminPanelTokens.cardRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: AdminPanelTokens.surfaceCard(context, scheme),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AdminPanelTokens.space16,
              vertical: AdminPanelTokens.space12,
            ),
            minVerticalPadding: AdminPanelTokens.space12,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${_shortId(id)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
            subtitle: Text(
              lastLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.25, color: scheme.onSurfaceVariant),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminStatusPill(
                  label: status,
                  variant: _statusVariantForOrder(statusRaw),
                ),
                const SizedBox(height: 6),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _cookIdCtrl;
  late final TextEditingController _customerIdCtrl;
  late final TabController _tabCtrl;
  bool _hydratedColumnFilters = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _cookIdCtrl = TextEditingController();
    _customerIdCtrl = TextEditingController();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchCtrl.text = ref.read(adminOrdersSearchQueryProvider);
      final target = ref.read(adminOrdersTargetTabProvider);
      if (target != null && target >= 0 && target < _tabCtrl.length) {
        _tabCtrl.index = target;
        ref.read(adminOrdersTargetTabProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _cookIdCtrl.dispose();
    _customerIdCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydratedColumnFilters) return;
    _hydratedColumnFilters = true;
    _cookIdCtrl.text = ref.read(adminOrdersChefIdFilterProvider) ?? '';
    _customerIdCtrl.text = ref.read(adminOrdersCustomerIdFilterProvider) ?? '';
  }

  void _applyColumnFilters() {
    final c = _cookIdCtrl.text.trim();
    final u = _customerIdCtrl.text.trim();
    ref.read(adminOrdersChefIdFilterProvider.notifier).state = c.isEmpty ? null : c;
    ref.read(adminOrdersCustomerIdFilterProvider.notifier).state = u.isEmpty ? null : u;
  }

  void _clearColumnFilters() {
    _cookIdCtrl.clear();
    _customerIdCtrl.clear();
    ref.read(adminOrdersChefIdFilterProvider.notifier).state = null;
    ref.read(adminOrdersCustomerIdFilterProvider.notifier).state = null;
    ref.read(adminOrdersDateFromProvider.notifier).state = null;
    ref.read(adminOrdersDateToProvider.notifier).state = null;
  }

  Future<void> _pickOrderDate({required bool isFrom}) async {
    final initial = isFrom
        ? ref.read(adminOrdersDateFromProvider) ?? DateTime.now()
        : ref.read(adminOrdersDateToProvider) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    if (isFrom) {
      ref.read(adminOrdersDateFromProvider.notifier).state = picked;
    } else {
      ref.read(adminOrdersDateToProvider.notifier).state = picked;
    }
  }

  void _applyOrderSearch() {
    ref.read(adminOrdersSearchQueryProvider.notifier).state = _searchCtrl.text.trim();
  }

  void _onOrderSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _applyOrderSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final async = ref.watch(adminOrdersListProvider);
    final appliedQuery = ref.watch(adminOrdersSearchQueryProvider);
    final stuckOnly = ref.watch(adminOrdersStuckOnlyProvider);
    final stuckSubtype = ref.watch(adminOrdersStuckSubtypeProvider);
    final dateFrom = ref.watch(adminOrdersDateFromProvider);
    final dateTo = ref.watch(adminOrdersDateToProvider);
    final chefF = ref.watch(adminOrdersChefIdFilterProvider);
    final custF = ref.watch(adminOrdersCustomerIdFilterProvider);
    final hasColumnFilters =
        (chefF != null && chefF.trim().isNotEmpty) ||
        (custF != null && custF.trim().isNotEmpty) ||
        dateFrom != null ||
        dateTo != null;

    ref.listen<int?>(adminOrdersTargetTabProvider, (prev, next) {
      if (next == null) return;
      if (next >= 0 && next < _tabCtrl.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _tabCtrl.index = next;
          ref.read(adminOrdersTargetTabProvider.notifier).state = null;
        });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active Orders'),
            Tab(text: 'Completed Orders'),
            Tab(text: 'Cancelled Orders'),
          ],
        ),
        actions: const [AdminSignOutIconButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stuckOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  title: const Text('Delayed orders'),
                  subtitle: const Text(
                    'Active orders with no update for 2+ hours',
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(adminOrdersStuckOnlyProvider.notifier).state = false;
                      ref.read(adminOrdersStuckSubtypeProvider.notifier).state = AdminOrdersStuckSubtype.any;
                    },
                    child: const Text('Clear'),
                  ),
                ),
              ),
            ),
          if (stuckOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any stage'),
                      selected: stuckSubtype == AdminOrdersStuckSubtype.any,
                      onSelected: (_) =>
                          ref.read(adminOrdersStuckSubtypeProvider.notifier).state = AdminOrdersStuckSubtype.any,
                    ),
                    ChoiceChip(
                      label: const Text('Accepted too long'),
                      selected: stuckSubtype == AdminOrdersStuckSubtype.acceptedLong,
                      onSelected: (_) => ref.read(adminOrdersStuckSubtypeProvider.notifier).state =
                          AdminOrdersStuckSubtype.acceptedLong,
                    ),
                    ChoiceChip(
                      label: const Text('Preparing too long'),
                      selected: stuckSubtype == AdminOrdersStuckSubtype.preparingLong,
                      onSelected: (_) => ref.read(adminOrdersStuckSubtypeProvider.notifier).state =
                          AdminOrdersStuckSubtype.preparingLong,
                    ),
                    ChoiceChip(
                      label: const Text('Ready too long'),
                      selected: stuckSubtype == AdminOrdersStuckSubtype.readyLong,
                      onSelected: (_) =>
                          ref.read(adminOrdersStuckSubtypeProvider.notifier).state = AdminOrdersStuckSubtype.readyLong,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cook, customer, or order ID',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => _onOrderSearchChanged(),
                    onSubmitted: (_) {
                      _searchDebounce?.cancel();
                      _applyOrderSearch();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _applyOrderSearch();
                  },
                ),
                if (appliedQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(adminOrdersSearchQueryProvider.notifier).state = '';
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              child: ExpansionTile(
                title: const Text('Column filters'),
                subtitle: Text(
                  hasColumnFilters
                      ? 'Cook / customer UUID and/or date range applied'
                      : 'Filter by cook, customer, or created date',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  TextField(
                    controller: _cookIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cook ID (UUID)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer ID (UUID)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickOrderDate(isFrom: true),
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(dateFrom == null ? 'From date' : 'From: ${dateFrom.toString().split(' ').first}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickOrderDate(isFrom: false),
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(dateTo == null ? 'To date' : 'To: ${dateTo.toString().split(' ').first}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _applyColumnFilters,
                        child: const Text('Apply filters'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: hasColumnFilters ? _clearColumnFilters : null,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading orders…',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ordersErrorIsOffline(e) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                        size: 48,
                        color: ordersErrorIsOffline(e) ? Colors.orange : Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        resolveOrdersUiError(e),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(adminOrdersListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  final hasFilters = appliedQuery.isNotEmpty ||
                      hasColumnFilters ||
                      stuckOnly;
                  return AdminEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: hasFilters ? 'No matching orders' : 'No orders yet',
                    subtitle: hasFilters
                        ? 'Adjust search, filters, or date range.'
                        : 'New orders will appear here when customers place them.',
                  );
                }
                final tab = _tabCtrl.index;
                var filtered = rows
                    .where((r) => AdminOrdersScreen._matchesOrderTab(
                          (r['status'] ?? '').toString(),
                          tab,
                        ))
                    .toList();
                if (stuckOnly) {
                  filtered = filtered.where((r) => AdminOrdersScreen._isStuckOrder(r, stuckSubtype)).toList();
                }
                if (filtered.isEmpty) {
                  final hasFilters = appliedQuery.isNotEmpty ||
                      hasColumnFilters ||
                      stuckOnly;
                  return AdminEmptyState(
                    icon: Icons.filter_alt_outlined,
                    title: hasFilters ? 'No matching orders in this tab' : 'No orders in this tab',
                    subtitle: hasFilters
                        ? 'Try another tab or clear filters.'
                        : 'Switch tabs to see active or completed orders.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = filtered[i];
                    final id = (r['id'] ?? '').toString();
                    return AdminOrdersScreen.orderMonitoringCard(
                      context,
                      r: r,
                      onTap: id.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => AdminOrderDetailScreen(orderId: id),
                                ),
                              );
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Same horizontal timeline as cook / customer order screens.
class _AdminOrderPipelineTimeline extends StatelessWidget {
  const _AdminOrderPipelineTimeline({required this.statusRaw});

  final String statusRaw;

  static const _stepLabels = ['Order Placed', 'Accepted', 'Preparing', 'Ready', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final r = statusRaw.trim();
    final scheme = Theme.of(context).colorScheme;
    if (r == 'rejected' || OrderDbStatus.cancelled.contains(r)) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_outlined, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r == 'rejected' ? 'Rejected' : 'Cancelled / closed',
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isCompleted = r == 'completed';
    int currentStepIndex;
    if (OrderDbStatus.pending.contains(r) || r == 'paid_waiting_acceptance') {
      currentStepIndex = 0;
    } else if (r == 'accepted') {
      currentStepIndex = 1;
    } else if (OrderDbStatus.preparing.contains(r)) {
      currentStepIndex = 2;
    } else if (r == 'ready') {
      currentStepIndex = 3;
    } else if (isCompleted) {
      currentStepIndex = 4;
    } else {
      currentStepIndex = 0;
    }

    final sub = scheme.onSurfaceVariant;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: List.generate(_stepLabels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIndex = i ~/ 2;
              final bothDone = isCompleted || stepIndex < currentStepIndex;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(left: 4, right: 4),
                  color: bothDone ? Colors.green : sub.withValues(alpha: 0.3),
                ),
              );
            }
            final stepIndex = i ~/ 2;
            final isCompletedStatus = isCompleted;
            final done = isCompletedStatus || stepIndex < currentStepIndex;
            final current = !isCompletedStatus && stepIndex == currentStepIndex;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? Colors.green : (current ? Colors.blue : Colors.transparent),
                    border: current || done ? null : Border.all(color: sub.withValues(alpha: 0.6), width: 2),
                    boxShadow: current
                        ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    _stepLabels[stepIndex],
                    style: TextStyle(
                      fontSize: 9,
                      color: done ? Colors.green : (current ? Colors.blue : sub),
                      fontWeight: current ? FontWeight.w700 : null,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class AdminOrderDetailScreen extends ConsumerWidget {
  const AdminOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final async = ref.watch(adminOrderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
        actions: [
          IconButton(
            tooltip: 'Open chat',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () {
              final id = orderId.trim();
              if (id.isEmpty) return;
              _openOrderChatForAdmin(context, id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminOrderDetailProvider(orderId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ordersErrorIsOffline(e) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                  size: 48,
                  color: ordersErrorIsOffline(e) ? Colors.orange : Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(resolveOrdersUiError(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(adminOrderDetailProvider(orderId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (payload) {
          if (payload == null) {
            return const Center(child: Text('Order not found'));
          }
          final order = Map<String, dynamic>.from(payload['order'] as Map? ?? {});
          final items = (payload['items'] as List?) ?? const [];
          final id = (order['id'] ?? '').toString();
          final rawSt = (order['status'] ?? '').toString();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Order #${AdminOrdersScreen._shortId(id)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              SelectableText(id, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              _AdminOrderPipelineTimeline(statusRaw: rawSt),
              const SizedBox(height: 16),
              _kv('Cook', (order['chef_name'] ?? order['chef_id'] ?? '—').toString()),
              _kv('Customer', (order['customer_name'] ?? order['customer_id'] ?? '—').toString()),
              _kv(
                'Status',
                AdminOrdersScreen.statusLabel(
                  rawSt,
                  cancelReason: order['cancel_reason']?.toString(),
                ),
              ),
              if ((order['cancel_reason'] as String?)?.trim().isNotEmpty == true)
                _kv('Internal cancel_reason', order['cancel_reason'] as String),
              const SizedBox(height: 16),
              _kv('Total', 'SAR ${AdminOrdersScreen._formatMoney(order['total_amount'])}'),
              _kv('Created', (order['created_at'] ?? '—').toString()),
              _kv('Updated', (order['updated_at'] ?? '—').toString()),
              if ((order['delivery_address'] as String?)?.trim().isNotEmpty == true)
                _kv('Address', order['delivery_address'] as String),
              if ((order['notes'] as String?)?.trim().isNotEmpty == true)
                _kv('Notes', order['notes'] as String),
              if ((order['rejection_reason'] as String?)?.trim().isNotEmpty == true)
                _kv('Rejection / cancel note', order['rejection_reason'] as String),
              const SizedBox(height: 20),
              const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...items.map<Widget>((raw) {
                final m = Map<String, dynamic>.from(raw as Map);
                final name = (m['dish_name'] ?? 'Item').toString();
                final qty = (m['quantity'] as num?)?.toInt() ?? 1;
                final price = AdminOrdersScreen._formatMoney(m['unit_price'] ?? m['price']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('$name × $qty')),
                      Text('SAR $price'),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

Future<void> _openOrderChatForAdmin(BuildContext context, String orderId) async {
  try {
    final row = await SupabaseConfig.client
        .from('conversations')
        .select('id')
        .eq('order_id', orderId)
        .eq('type', 'customer-chef')
        .maybeSingle();
    final cid = row?['id']?.toString();
    if (cid == null || cid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chat for this order yet')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminSupportConversationScreen(
          chatId: cid,
          title: 'Chat',
          conversationType: 'customer-chef',
          monitorOnly: true,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open chat: $e')),
    );
  }
}
