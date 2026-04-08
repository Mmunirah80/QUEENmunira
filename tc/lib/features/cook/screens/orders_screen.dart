// ============================================================
// COOK ORDERS SCREEN — Naham App, Supabase real-time
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../features/orders/presentation/orders_failure.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/naham_empty_screens.dart';
import '../../../core/widgets/naham_screen_header.dart';
import '../../../features/orders/domain/entities/order_entity.dart';
import '../../../features/orders/presentation/mappers/order_ui_mapper.dart';
import '../../../features/orders/presentation/providers/orders_provider.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../chat/presentation/providers/chat_provider.dart';
import '../../customer/presentation/providers/customer_providers.dart';
import '_order_reject_helper.dart';
import 'chat_screen.dart';
import 'order_details_screen.dart';

class _NC {
  static const primaryMid = Color(0xFF9B7EC8);
  static const primaryLight = Color(0xFFE8E4F0);
  static const bg = Color(0xFFF5F0FF);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textSub = Color(0xFF6B7280);
  static const border = Color(0xFFE8E0F5);
  static const error = Color(0xFFE74C3C);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF2ECC71);
  static const almostReady = Color(0xFFF5A623);
}

const Duration _delayedThreshold = Duration(minutes: 30);

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  bool _isQaOrder(OrderEntity order) {
    final n = (order.notes ?? '').toLowerCase();
    return n.contains('qa auto order');
  }

  late TabController _tab;
  final Set<String> _statusUpdatingOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final cookId = user?.id ?? '';
    final newAsync = ref.watch(chefNewOrdersStreamProvider);
    final activeAsync = ref.watch(chefActiveOrdersStreamProvider);
    final completedAsync = ref.watch(chefCompletedOrdersStreamProvider);
    final cancelledAsync = ref.watch(chefCancelledOrdersStreamProvider);

    final mockOrders = ref.watch(cookOrdersUsingMockProvider);

    return Scaffold(
      backgroundColor: _NC.bg,
      body: Column(
        children: [
          const NahamScreenHeader(title: 'Orders'),
          if (mockOrders)
            Material(
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.science_outlined, size: 18, color: Colors.green.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mock orders: sample data for QA only. '
                        'Real Supabase is the default; enable mock with '
                        '--dart-define=COOK_MOCK_ORDERS=true',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (cookId.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Please sign in',
                    style: TextStyle(fontSize: 16, color: _NC.textSub),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else ...[
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tab,
                indicatorColor: AppDesignSystem.primaryDark,
                labelColor: AppDesignSystem.primaryDark,
                unselectedLabelColor: _NC.textSub,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'New'),
                  Tab(text: 'Active'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildNewTab(newAsync),
                  _buildActiveTab(activeAsync),
                  _buildCompletedTab(completedAsync),
                  _buildCancelledTab(cancelledAsync),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewTab(AsyncValue<List<OrderEntity>> newAsync) {
    return newAsync.when(
      data: (orders) {
        final visible = orders.where((o) => !_isQaOrder(o)).toList();
        if (visible.isEmpty) {
          return Center(
            child: NahamEmptyStateContent(
              title: 'No new orders',
              subtitle: 'New orders will appear here when customers place them.',
              buttonLabel: 'Refresh',
              onPressed: () => ref.invalidate(chefNewOrdersStreamProvider),
              fallbackIcon: Icons.inbox_rounded,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(chefNewOrdersStreamProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            itemBuilder: (ctx, i) {
            final order = visible[i];
            final isDelayed = DateTime.now().difference(order.createdAt) > _delayedThreshold;
            final map = OrderUiMapper.toNewOrderMap(order);
            final detailsMap = OrderUiMapper.toDetailsMapNew(order);
            return _OrderCard(
              order: order,
              map: map,
              detailsMap: detailsMap,
              orderType: 'new',
              isDelayed: isDelayed,
              onAccept: _statusUpdatingOrderIds.contains(order.id) ? null : () => _accept(order.id),
              onReject: _statusUpdatingOrderIds.contains(order.id) ? null : () => _showRejectReasons(ctx, order.id),
              onAutoExpire: () => _autoExpire(order.id),
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailsScreen(
                    order: detailsMap,
                    orderType: 'new',
                    orderId: order.id,
                    orderEntity: order,
                  ),
                ),
              ),
            );
            },
          ),
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (err, _) => Center(
        child: ErrorStateContent(
          message: resolveOrdersUiError(err),
          fallbackIcon:
              ordersErrorIsOffline(err) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          onRetry: () => ref.invalidate(chefNewOrdersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildActiveTab(AsyncValue<List<OrderEntity>> activeAsync) {
    return activeAsync.when(
      data: (orders) {
        final visible = orders.where((o) => !_isQaOrder(o)).toList();
        if (visible.isEmpty) {
          return Center(
            child: NahamEmptyStateContent(
              title: 'No active orders',
              subtitle: 'Accepted and in-progress orders will appear here.',
              buttonLabel: 'Refresh',
              onPressed: () => ref.invalidate(chefActiveOrdersStreamProvider),
              fallbackIcon: Icons.pending_actions_rounded,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(chefActiveOrdersStreamProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            itemBuilder: (ctx, i) {
            final order = visible[i];
            final isDelayed = DateTime.now().difference(order.createdAt) > _delayedThreshold;
            final map = OrderUiMapper.toActiveOrderMap(order);
            final detailsMap = OrderUiMapper.toDetailsMapActive(order);
            return _OrderCard(
              order: order,
              map: map,
              detailsMap: detailsMap,
              orderType: 'active',
              isDelayed: isDelayed,
              onChat: () => _openChatWithCustomer(ctx, order),
              onAdvanceStatus: _statusUpdatingOrderIds.contains(order.id) ? null : () async {
                final currentStatus = order.status;
                OrderStatus? next;
                if (currentStatus == OrderStatus.accepted) {
                  next = OrderStatus.preparing;
                } else if (currentStatus == OrderStatus.preparing) {
                  next = OrderStatus.ready;
                } else if (currentStatus == OrderStatus.ready) {
                  next = OrderStatus.completed;
                }
                if (next == null) return;
                try {
                  setState(() => _statusUpdatingOrderIds.add(order.id));
                  await ref.read(ordersRepositoryProvider).updateOrderStatus(order.id, next);
                } catch (e) {
                  if (ctx.mounted) {
                    SnackbarHelper.error(ctx, resolveOrdersUiError(e));
                  }
                } finally {
                  if (mounted) {
                    setState(() => _statusUpdatingOrderIds.remove(order.id));
                  }
                }
              },
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailsScreen(
                    order: detailsMap,
                    orderType: 'active',
                    orderId: order.id,
                    orderEntity: order,
                  ),
                ),
              ),
            );
            },
          ),
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (err, _) => Center(
        child: ErrorStateContent(
          message: resolveOrdersUiError(err),
          fallbackIcon:
              ordersErrorIsOffline(err) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          onRetry: () => ref.invalidate(chefActiveOrdersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildCompletedTab(AsyncValue<List<OrderEntity>> completedAsync) {
    return completedAsync.when(
      data: (orders) {
        final visible = orders.where((o) => !_isQaOrder(o)).toList();
        if (visible.isEmpty) {
          return Center(
            child: NahamEmptyStateContent(
              title: 'No completed orders',
              subtitle: 'Completed orders will appear here.',
              buttonLabel: 'Refresh',
              onPressed: () => ref.invalidate(chefCompletedOrdersStreamProvider),
              fallbackIcon: Icons.check_circle_outline_rounded,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(chefCompletedOrdersStreamProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            itemBuilder: (ctx, i) {
            final order = visible[i];
            final map = OrderUiMapper.toCompletedOrderMap(order);
            final detailsMap = OrderUiMapper.toDetailsMapCompleted(order);
            return _OrderCard(
              order: order,
              map: map,
              detailsMap: detailsMap,
              orderType: 'completed',
              isDelayed: false,
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailsScreen(
                    order: detailsMap,
                    orderType: 'completed',
                    orderId: order.id,
                    orderEntity: order,
                  ),
                ),
              ),
            );
            },
          ),
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (err, _) => Center(
        child: ErrorStateContent(
          message: resolveOrdersUiError(err),
          fallbackIcon:
              ordersErrorIsOffline(err) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          onRetry: () => ref.invalidate(chefCompletedOrdersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildCancelledTab(AsyncValue<List<OrderEntity>> cancelledAsync) {
    return cancelledAsync.when(
      data: (orders) {
        final visible = orders.where((o) => !_isQaOrder(o)).toList();
        if (visible.isEmpty) {
          return Center(
            child: NahamEmptyStateContent(
              title: 'No cancelled orders',
              subtitle: 'Rejected or cancelled orders will appear here.',
              buttonLabel: 'Refresh',
              onPressed: () => ref.invalidate(chefCancelledOrdersStreamProvider),
              fallbackIcon: Icons.cancel_outlined,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(chefCancelledOrdersStreamProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length,
            itemBuilder: (ctx, i) {
            final order = visible[i];
            final map = OrderUiMapper.toCancelledOrderMap(order);
            final detailsMap = OrderUiMapper.toDetailsMapCancelled(order);
            return _OrderCard(
              order: order,
              map: map,
              detailsMap: detailsMap,
              orderType: 'cancelled',
              isDelayed: false,
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) => OrderDetailsScreen(
                    order: detailsMap,
                    orderType: 'cancelled',
                    orderId: order.id,
                    orderEntity: order,
                  ),
                ),
              ),
            );
            },
          ),
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (err, _) => Center(
        child: ErrorStateContent(
          message: resolveOrdersUiError(err),
          fallbackIcon:
              ordersErrorIsOffline(err) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          onRetry: () => ref.invalidate(chefCancelledOrdersStreamProvider),
        ),
      ),
    );
  }

  Future<void> _accept(String orderId) async {
    if (_statusUpdatingOrderIds.contains(orderId)) return;
    try {
      setState(() => _statusUpdatingOrderIds.add(orderId));
      await ref.read(ordersRepositoryProvider).acceptOrder(orderId);
      // Streams update from mock _emit / Supabase realtime; invalidating re-subscribes
      // and can briefly show empty or duplicate state with broadcast mock bus.
    } catch (e) {
      debugPrint('[CookOrders] accept error=$e');
      if (mounted) {
        SnackbarHelper.error(context, resolveOrdersUiError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _statusUpdatingOrderIds.remove(orderId));
      }
    }
  }

  Future<void> _showRejectReasons(BuildContext context, String orderId) async {
    if (_statusUpdatingOrderIds.contains(orderId)) return;
    final reason = await showRejectReasonSheet(context);
    if (reason == null || !mounted) return;
    try {
      setState(() => _statusUpdatingOrderIds.add(orderId));
      await ref.read(ordersRepositoryProvider).rejectOrder(orderId, reason: reason);
      // Stock restore: handled by transition_order_status / restore_order_stock_once on the server.
    } catch (e) {
      debugPrint('[CookOrders] reject error=$e');
      if (context.mounted) {
        SnackbarHelper.error(context, resolveOrdersUiError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _statusUpdatingOrderIds.remove(orderId));
      }
    }
  }

  Future<void> _autoExpire(String orderId) async {
    if (_statusUpdatingOrderIds.contains(orderId)) return;
    try {
      setState(() => _statusUpdatingOrderIds.add(orderId));
      await ref.read(ordersRepositoryProvider).rejectOrder(orderId, reason: 'Time expired');
    } finally {
      if (mounted) {
        setState(() => _statusUpdatingOrderIds.remove(orderId));
      }
    }
  }

  Future<void> _openChatWithCustomer(BuildContext context, OrderEntity order) async {
    final customerId = order.customerId;
    if (customerId == null || customerId.isEmpty) {
      if (context.mounted) {
        SnackbarHelper.error(context, 'Customer not found for this order.');
      }
      return;
    }
    try {
      final chatId = await ref.read(chatRepositoryProvider).getOrCreateConversation(customerId);
      final chefUid = ref.read(authStateProvider).valueOrNull?.id ?? '';
      if (chefUid.isNotEmpty && order.id.isNotEmpty) {
        await ref.read(customerChatSupabaseDataSourceProvider).tryLinkCustomerChefConversationToOrder(
              conversationId: chatId,
              orderId: order.id,
              customerId: customerId,
              chefId: chefUid,
            );
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CookChatConversationScreen(
            name: order.customerName,
            chatId: chatId,
            orderId: order.id,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.error(context, resolveOrdersUiError(e));
      }
    }
  }
}

class _OrderCard extends StatelessWidget {
  final OrderEntity order;
  final Map<String, dynamic> map;
  final Map<String, dynamic> detailsMap;
  final String orderType;
  final bool isDelayed;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onTap;
  final VoidCallback? onAutoExpire;
  final VoidCallback? onChat;
  final VoidCallback? onAdvanceStatus;

  const _OrderCard({
    required this.order,
    required this.map,
    required this.detailsMap,
    required this.orderType,
    required this.isDelayed,
    this.onAccept,
    this.onReject,
    this.onTap,
    this.onAutoExpire,
    this.onChat,
    this.onAdvanceStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isNew = orderType == 'new';
    final isCompleted = orderType == 'completed';
    final isCancelled = orderType == 'cancelled';
    final oid = order.id;
    final chatOrderRef = oid.length > 8 ? oid.substring(oid.length - 8) : oid;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _NC.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDelayed ? Border.all(color: _NC.warning, width: 2) : null,
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${OrderUiMapper.shortOrderId(order.id)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _NC.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (order.id.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                order.id,
                                style: const TextStyle(fontSize: 11, color: _NC.textSub, height: 1.2),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          map['customer'] as String,
                          style: const TextStyle(fontSize: 13, color: _NC.textSub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDelayed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _NC.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Delayed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _NC.warning,
                            ),
                          ),
                        )
                      else if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _NC.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _NC.primaryMid,
                            ),
                          ),
                        )
                      else if (isCancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _NC.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            map['status'] as String? ?? 'Cancelled',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _NC.error,
                            ),
                          ),
                        )
                      else if (!isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _NC.almostReady.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            map['status'] as String? ?? 'Active',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _NC.almostReady,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    map['items'] as String,
                    style: const TextStyle(fontSize: 13, color: _NC.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${((map['amount'] ?? map['earnings']) as num?)?.toStringAsFixed(2) ?? '0.00'} SAR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _NC.primaryMid,
                    ),
                  ),
                  if (isNew)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _NewOrderCountdown(
                        createdAt: order.createdAt,
                        onExpired: onAutoExpire,
                      ),
                    ),
                  if (isNew && (order.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBE6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFE58F)),
                      ),
                      child: Text(
                        order.notes!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8A6914)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isNew && (onAccept != null || onReject != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _NC.error,
                          side: const BorderSide(color: _NC.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _NC.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (orderType == 'active')
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _NC.border)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onChat,
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: Text('Chat · #$chatOrderRef'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _NC.primaryMid,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onAdvanceStatus,
                          icon: Icon(
                            order.status == OrderStatus.accepted
                                ? Icons.local_dining_rounded
                                : order.status == OrderStatus.preparing
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.done_all_rounded,
                            size: 16,
                          ),
                          label: Text(
                            order.status == OrderStatus.accepted
                                ? 'Start Preparing'
                                : order.status == OrderStatus.preparing
                                    ? 'Mark Ready'
                                    : 'Complete',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _NC.primaryMid,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (isCancelled) ...[
              if ((order.notes ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _NC.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18, color: _NC.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cancellation reason',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _NC.textSub,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.notes!,
                              style: const TextStyle(fontSize: 13, color: _NC.text),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: _NC.primaryMid,
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ] else if (!isCompleted)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _NC.border)),
                ),
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: _NC.primaryMid,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _NewOrderCountdown extends StatefulWidget {
  final DateTime createdAt;
  final VoidCallback? onExpired;

  const _NewOrderCountdown({
    required this.createdAt,
    this.onExpired,
  });

  @override
  State<_NewOrderCountdown> createState() => _NewOrderCountdownState();
}

class _NewOrderCountdownState extends State<_NewOrderCountdown> {
  static const Duration _total = Duration(minutes: 5);
  Duration _remaining = Duration.zero;
  bool _expiredHandled = false;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _ticker = Ticker(_onTick)..start();
    if (_remaining <= Duration.zero) {
      _handleExpired();
    }
  }

  Duration _computeRemaining() {
    final elapsed = DateTime.now().difference(widget.createdAt);
    final rem = _total - elapsed;
    return rem.isNegative ? Duration.zero : rem;
  }

  void _onTick(Duration _) {
    final rem = _computeRemaining();
    if (!mounted) return;
    setState(() {
      _remaining = rem;
    });
    if (rem <= Duration.zero) {
      _handleExpired();
    }
  }

  void _handleExpired() {
    if (_expiredHandled) return;
    _expiredHandled = true;
    _ticker.stop();
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = _remaining.inSeconds;
    final minutes = secs ~/ 60;
    final seconds = secs % 60;
    final text = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isUrgent = _remaining.inMinutes < 1;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: isUrgent ? _NC.error : _NC.textSub,
        fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
