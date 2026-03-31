// ============================================================
// CUSTOMER ORDER DETAILS — Full order details, status, items, cook info, chat button.
// Data from Supabase via customerOrderByIdStreamProvider.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/features/orders/presentation/mappers/order_ui_mapper.dart';
import 'package:naham_cook_app/features/orders/presentation/orders_failure.dart';
import 'package:naham_cook_app/features/orders/presentation/widgets/orders_stream_error_panel.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';
import 'package:naham_cook_app/features/orders/data/models/order_model.dart';
import 'package:naham_cook_app/features/customer/data/datasources/customer_orders_supabase_datasource.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_chat_screen.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

class CustomerOrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const CustomerOrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<CustomerOrderDetailsScreen> createState() => _CustomerOrderDetailsScreenState();
}

class _CustomerOrderDetailsScreenState extends ConsumerState<CustomerOrderDetailsScreen> {
  bool _cancelling = false;

  Future<void> _onRefresh() async {
    ref.invalidate(customerOrderByIdStreamProvider(widget.orderId));
    await ref.read(customerOrderByIdStreamProvider(widget.orderId).future);
  }

  Future<void> _confirmAndCancelOrder(String orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'You can cancel while the cook has not accepted yet. Items return to availability.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await CustomerOrdersSupabaseDatasource().cancelOrderByCustomer(orderId);
      ref.invalidate(customerOrderByIdStreamProvider(orderId));
      ref.invalidate(customerOrdersStreamProvider);
      if (mounted) {
        SnackbarHelper.success(context, 'Order cancelled');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.error(context, resolveOrdersUiError(e));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(customerOrderByIdStreamProvider(widget.orderId));

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        title: const Text('Order Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return RefreshIndicator(
              color: _C.primary,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: _C.textSub),
                            const SizedBox(height: 12),
                            const Text('Order not found', textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text(
                              'Pull to refresh or check your orders list.',
                              style: TextStyle(fontSize: 13, color: _C.textSub.withValues(alpha: 0.9)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: _C.primary,
            onRefresh: _onRefresh,
            child: _OrderContent(
              order: order,
              isCancelling: _cancelling,
              onCancelPressed: () => _confirmAndCancelOrder(order.id),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _C.primary)),
        error: (e, _) => Center(
          child: OrdersStreamErrorPanel(
            error: e,
            onRetry: () => ref.invalidate(customerOrderByIdStreamProvider(widget.orderId)),
          ),
        ),
      ),
    );
  }
}

class _OrderContent extends ConsumerWidget {
  final OrderModel order;
  final bool isCancelling;
  final VoidCallback onCancelPressed;

  const _OrderContent({
    required this.order,
    required this.isCancelling,
    required this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order.status;
    final chefId = order.chefId;
    final chefName = order.chefName ?? '—';
    final chefs = ref.watch(chefsForCustomerStreamProvider).valueOrNull ?? [];
    final chef = chefs.where((c) => c.chefId == chefId).firstOrNull;
    final kitchenName = chef?.kitchenName ?? '';
    final kitchenCity = chef?.kitchenCity ?? '';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == OrderStatus.cancelled || status == OrderStatus.rejected) ...[
            Card(
              color: Colors.red.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.cancel, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Order Cancelled',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        order.notes!,
                        style: const TextStyle(fontSize: 13, color: _C.textSub),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _OrderStatusTimeline(order: order),
            const SizedBox(height: 16),
            if (status == OrderStatus.pending) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Waiting for cook to accept...',
                  style: TextStyle(fontSize: 14, color: _C.textSub),
                  textAlign: TextAlign.center,
                ),
              ),
              OutlinedButton.icon(
                onPressed: isCancelling ? null : onCancelPressed,
                icon: isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.errorRed),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: Text(isCancelling ? 'Cancelling…' : 'Cancel order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignSystem.errorRed,
                  side: const BorderSide(color: AppDesignSystem.errorRed),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
          _StatusCard(status: status),
          const SizedBox(height: 16),
          _InfoRow('Order', '#${OrderUiMapper.shortOrderId(order.id)}'),
          _InfoRow('Cook', chefName),
          if (kitchenName.isNotEmpty) _InfoRow('Kitchen', kitchenName),
          if (kitchenCity.isNotEmpty) _InfoRow('City', kitchenCity),
          _InfoRow('Date', _formatDate(order.createdAt)),
          if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
            _InfoRow('Pickup / meet point', order.deliveryAddress!),
          const SizedBox(height: 16),
          const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.text)),
          const SizedBox(height: 8),
          ...order.items.map((item) => _ItemRow(item: item)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text)),
              Text(
                '${order.totalAmount.toStringAsFixed(1)} SAR',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (status == OrderStatus.pending) ...[
            Text(
              'Chat opens after the cook accepts this order.',
              style: TextStyle(fontSize: 13, color: _C.textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: chefId == null || chefId.isEmpty || !_canCustomerChatWithCook(status)
                ? null
                : () => _openCustomerCookChat(
                      context,
                      ref,
                      orderId: order.id,
                      chefId: chefId,
                      chefName: chefName,
                    ),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat with Cook'),
            style: FilledButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

bool _canCustomerChatWithCook(OrderStatus status) {
  switch (status) {
    case OrderStatus.accepted:
    case OrderStatus.preparing:
    case OrderStatus.ready:
    case OrderStatus.completed:
      return true;
    case OrderStatus.pending:
    case OrderStatus.rejected:
    case OrderStatus.cancelled:
      return false;
  }
}

Future<void> _openCustomerCookChat(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
  required String chefId,
  required String chefName,
}) async {
  final uid = ref.read(customerIdProvider);
  if (uid.isEmpty) {
    SnackbarHelper.error(context, 'Please sign in to chat');
    return;
  }

  void dismissLoader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    });
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
  );

  try {
    final conversationId =
        await ref.read(customerChatSupabaseDataSourceProvider).getOrCreateCustomerChefChat(
              customerId: uid,
              chefId: chefId,
              chefName: chefName.isNotEmpty ? chefName : 'Cook',
              linkOrderId: orderId,
            );
    dismissLoader();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NahamCustomerChatConversationScreen(
          chatId: conversationId,
          name: chefName.isNotEmpty ? chefName : 'Cook',
        ),
      ),
    );
  } catch (e) {
    dismissLoader();
    if (context.mounted) {
      SnackbarHelper.error(context, resolveOrdersUiError(e));
    }
  }
}

/// Status timeline for active orders: Order Placed → Accepted → Preparing → Ready → Completed.
class _OrderStatusTimeline extends StatelessWidget {
  final OrderModel order;

  const _OrderStatusTimeline({required this.order});

  static const _stepLabels = ['Order Placed', 'Accepted', 'Preparing', 'Ready', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    // Current step index mapping (0-based):
    // pending   -> 0 (Order Placed highlighted)
    // accepted  -> 1
    // preparing -> 2
    // ready     -> 3
    // completed -> 4
    final currentStepIndex = status == OrderStatus.pending
        ? 0
        : status == OrderStatus.accepted
            ? 1
            : status == OrderStatus.preparing
                ? 2
                : status == OrderStatus.ready
                    ? 3
                    : 4;
    // Keep this widget identical to the cook timeline design.
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: List.generate(_stepLabels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIndex = i ~/ 2;
              final bothDone = status == OrderStatus.completed || stepIndex < currentStepIndex;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(left: 4, right: 4),
                  color: bothDone ? Colors.green : _C.textSub.withValues(alpha: 0.3),
                ),
              );
            }
            final stepIndex = i ~/ 2;
            final isCompletedStatus = status == OrderStatus.completed;
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
                    border: current || done ? null : Border.all(color: _C.textSub.withValues(alpha: 0.6), width: 2),
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
                      color: done ? Colors.green : (current ? Colors.blue : _C.textSub),
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

class _StatusCard extends StatelessWidget {
  final OrderStatus status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(_statusIcon(status), color: _C.primary, size: 28),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text)),
          ],
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'Waiting for acceptance';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData _statusIcon(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.accepted:
        return Icons.check_circle_outline;
      case OrderStatus.rejected:
        return Icons.cancel_outlined;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.done_all;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: _C.textSub))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: _C.text))),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItemEntity item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text('${item.dishName} × ${item.quantity}', style: const TextStyle(color: _C.text)),
          ),
          Text(
            '${(item.price * item.quantity).toStringAsFixed(1)} SAR',
            style: const TextStyle(color: _C.textSub),
          ),
        ],
      ),
    );
  }
}
