// ============================================================
// CUSTOMER ORDERS — 3 tabs: Active, Completed, Cancelled. Supabase.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/features/orders/presentation/mappers/order_ui_mapper.dart';
import 'package:naham_cook_app/features/orders/presentation/widgets/orders_stream_error_panel.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/orders/data/models/order_model.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';
import 'package:naham_cook_app/features/customer/screens/customer_order_details_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_waiting_for_chef_screen.dart';
import 'package:naham_cook_app/features/customer/widgets/pending_chef_response_countdown.dart';
import 'package:naham_cook_app/features/customer/widgets/skeleton_box.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

bool _isActive(OrderModel o) =>
    o.status == OrderStatus.pending ||
    o.status == OrderStatus.accepted ||
    o.status == OrderStatus.preparing ||
    o.status == OrderStatus.ready;
bool _isCompleted(OrderModel o) => o.status == OrderStatus.completed;
bool _isCancelled(OrderModel o) =>
    o.status == OrderStatus.cancelled || o.status == OrderStatus.rejected;

class CustomerOrdersScreen extends ConsumerStatefulWidget {
  final List<String> highlightedOrderIds;

  const CustomerOrdersScreen({
    super.key,
    this.highlightedOrderIds = const <String>[],
  });

  @override
  ConsumerState<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends ConsumerState<CustomerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Set<String> _highlightedOrderIds;
  bool _showOnlyHighlighted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _highlightedOrderIds = widget.highlightedOrderIds.toSet();
    _showOnlyHighlighted = _highlightedOrderIds.isNotEmpty;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
        '[CustomerOrders] customerId=${ref.read(customerIdProvider)} auth=${ref.read(authStateProvider).valueOrNull?.id}',
      );
    }
    final authAsync = ref.watch(authStateProvider);
    if (authAsync.isLoading) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: _customerOrdersAppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const SkeletonBox(height: 180, borderRadius: 16),
          ),
        ),
      );
    }
    if (authAsync.hasError) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: _customerOrdersAppBar(),
        body: Center(
          child: OrdersStreamErrorPanel(
            error: authAsync.error!,
            onRetry: () => ref.invalidate(authStateProvider),
          ),
        ),
      );
    }
    final user = authAsync.valueOrNull;
    final customerId = user?.id ?? '';
    if (customerId.isEmpty) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: _customerOrdersAppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Please sign in to view orders',
              style: TextStyle(fontSize: 16, color: _C.textSub),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final ordersAsync = ref.watch(customerOrdersStreamProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _customerOrdersAppBar(
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: ordersAsync.when(
        data: (allOrders) {
          if (kDebugMode) {
            debugPrint('[CustomerOrders] count=${allOrders.length}');
          }
          if (customerId.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Please sign in to view orders',
                  style: const TextStyle(fontSize: 16, color: _C.textSub),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final active = allOrders.where(_isActive).toList();
          final completed = allOrders.where(_isCompleted).toList();
          final cancelled = allOrders.where(_isCancelled).toList();
          if (kDebugMode) {
            debugPrint(
              '[CustomerOrders] active=${active.length} completed=${completed.length} cancelled=${cancelled.length}',
            );
          }

          final activeFiltered = _showOnlyHighlighted
              ? active.where((o) => _highlightedOrderIds.contains(o.id)).toList()
              : active;
          return Column(
            children: [
              if (_highlightedOrderIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showOnlyHighlighted
                              ? 'Showing newly placed orders'
                              : 'Showing all active orders',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _C.textSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _showOnlyHighlighted = !_showOnlyHighlighted);
                        },
                        icon: Icon(
                          _showOnlyHighlighted
                              ? Icons.filter_alt_rounded
                              : Icons.filter_alt_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _showOnlyHighlighted ? 'Newly placed' : 'All',
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OrderList(
                      orders: activeFiltered,
                      emptyMessage: 'No active orders',
                      onRefresh: () async {
                        ref.invalidate(customerOrdersStreamProvider);
                        await ref.read(customerOrdersStreamProvider.future);
                      },
                    ),
                    _OrderList(
                      orders: completed,
                      emptyMessage: 'No completed orders',
                      onRefresh: () async {
                        ref.invalidate(customerOrdersStreamProvider);
                        await ref.read(customerOrdersStreamProvider.future);
                      },
                    ),
                    _OrderList(
                      orders: cancelled,
                      emptyMessage: 'No cancelled orders',
                      onRefresh: () async {
                        ref.invalidate(customerOrdersStreamProvider);
                        await ref.read(customerOrdersStreamProvider.future);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const SkeletonBox(height: 180, borderRadius: 16),
          ),
        ),
        error: (e, _) => Center(
          child: OrdersStreamErrorPanel(
            error: e,
            onRetry: () => ref.invalidate(customerOrdersStreamProvider),
          ),
        ),
      ),
    );
  }
}

PreferredSizeWidget _customerOrdersAppBar({PreferredSizeWidget? bottom}) {
  return AppBar(
    backgroundColor: _C.primary,
    foregroundColor: Colors.white,
    centerTitle: false,
    titleSpacing: 12,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppDesignSystem.logoAsset,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 8),
        const Text('Naham', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    ),
    bottom: bottom,
  );
}

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMessage;
  final Future<void> Function()? onRefresh;

  const _OrderList({
    required this.orders,
    required this.emptyMessage,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      final empty = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined, size: 44, color: _C.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 16, color: _C.textSub),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
      if (onRefresh == null) return empty;
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: _C.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(hasScrollBody: false, child: empty),
          ],
        ),
      );
    }

    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final order = orders[i];
        return _OrderCard(
          order: order,
          onTap: () {
            if (order.status == OrderStatus.pending) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CustomerWaitingForChefScreen(orderId: order.id),
                ),
              );
            } else {
              Navigator.push(
                context,
                PageRouteBuilder<void>(
                  pageBuilder: (context, animation, secondaryAnimation) => CustomerOrderDetailsScreen(orderId: order.id),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    final offsetTween = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offsetTween, child: child),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            }
          },
        );
      },
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: _C.primary,
      child: list,
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(order.createdAt);
    final statusStr = OrderDbStatus.customerFacingLabel(
      order.dbStatus,
      cancelReason: order.cancelReason,
      orderStatusFallback: order.status,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${OrderUiMapper.shortOrderId(order.id)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _C.primary,
                        ),
                      ),
                      if (order.id.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          order.id,
                          style: const TextStyle(fontSize: 11, color: _C.textSub, height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBadgeBg(order.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusBadgeFg(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: _C.textSub),
              ),
              if (order.status == OrderStatus.pending) ...[
                const SizedBox(height: 8),
                PendingChefResponseCountdown(
                  createdAtUtc: order.createdAt,
                  strongColor: _C.primary,
                  mutedColor: _C.textSub,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                order.chefName ?? 'Cook',
                style: const TextStyle(fontWeight: FontWeight.w600, color: _C.text),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(color: _C.textSub)),
                  Text(
                    '${order.totalAmount.toStringAsFixed(1)} SAR',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _C.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  // Badge background colors:
  // green = completed, red = cancelled, blue = pending/accepted,
  // orange = preparing, purple = ready.
  Color _statusBadgeBg(OrderStatus s) {
    switch (s) {
      case OrderStatus.completed:
        return Colors.green.withValues(alpha: 0.2);
      case OrderStatus.cancelled:
        return Colors.red.withValues(alpha: 0.2);
      case OrderStatus.rejected:
        return Colors.red.withValues(alpha: 0.2);
      case OrderStatus.pending:
      case OrderStatus.accepted:
        return Colors.blue.withValues(alpha: 0.15);
      case OrderStatus.preparing:
        return Colors.orange.withValues(alpha: 0.15);
      case OrderStatus.ready:
        return Colors.purple.withValues(alpha: 0.15);
    }
  }

  Color _statusBadgeFg(OrderStatus s) {
    switch (s) {
      case OrderStatus.completed:
        return Colors.green.shade700;
      case OrderStatus.cancelled:
        return Colors.red.shade700;
      case OrderStatus.rejected:
        return Colors.red.shade700;
      case OrderStatus.pending:
      case OrderStatus.accepted:
        return Colors.blue.shade700;
      case OrderStatus.preparing:
        return Colors.orange.shade700;
      case OrderStatus.ready:
        return Colors.purple.shade700;
    }
  }
}
