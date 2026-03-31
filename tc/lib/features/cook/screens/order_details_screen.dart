// ============================================================
// ORDER DETAILS — Full screen when cook taps an order (NAHAM purple)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../../../features/customer/presentation/providers/customer_providers.dart';
import 'chat_screen.dart';
import '../../../features/orders/domain/entities/order_entity.dart';
import '../../../features/orders/presentation/providers/orders_provider.dart';
import '_order_reject_helper.dart';

class _C {
  static const primary = Color(0xFF9B7EC8);
  static const primaryLight = Color(0xFFE8E4F0);
  static const bg = Color(0xFFF5F0FF);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textSub = Color(0xFF6B7280);
  static const error = Color(0xFFE74C3C);
  static const success = Color(0xFF2ECC71);
  static const cooking = Color(0xFF9B7EC8);
  static const almostReady = Color(0xFFF5A623);
}

/// Derives UI tab phase from live status so detail screen updates after accept / advance without popping.
String _cookOrderPhase(OrderEntity? entity, String fallbackNavType) {
  if (entity == null) return fallbackNavType;
  switch (entity.status) {
    case OrderStatus.pending:
      return 'new';
    case OrderStatus.accepted:
    case OrderStatus.preparing:
    case OrderStatus.ready:
      return 'active';
    case OrderStatus.completed:
      return 'completed';
    case OrderStatus.rejected:
    case OrderStatus.cancelled:
      return 'cancelled';
  }
}

String _cookStatusAppBarLabel(OrderStatus? s) {
  if (s == null) return 'Active';
  switch (s) {
    case OrderStatus.pending:
      return 'New';
    case OrderStatus.accepted:
      return 'Accepted';
    case OrderStatus.preparing:
      return 'Preparing';
    case OrderStatus.ready:
      return 'Ready';
    case OrderStatus.completed:
      return 'Completed';
    case OrderStatus.cancelled:
    case OrderStatus.rejected:
      return 'Cancelled';
  }
}

Color _cookStatusAppBarChipColor(OrderStatus? s) {
  switch (s) {
    case OrderStatus.preparing:
      return _C.cooking;
    case OrderStatus.ready:
      return _C.almostReady;
    case OrderStatus.accepted:
      return _C.success;
    case OrderStatus.pending:
      return Colors.white;
    default:
      return _C.almostReady;
  }
}

final _orderStatusActionInProgressProvider = StateProvider.autoDispose<bool>((ref) => false);

/// [order] same map shape as in OrdersScreen (new/active/completed).
/// [orderType] 'new' | 'active' | 'completed'.
/// [orderId] used to call repository accept/reject/updateStatus.
/// [orderEntity] when set, shows full items (name, qty, price per line) and customer/delivery details.
class OrderDetailsScreen extends ConsumerWidget {
  final Map<String, dynamic> order;
  final String orderType;
  final String? orderId;
  final OrderEntity? orderEntity;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.orderType,
    this.orderId,
    this.orderEntity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionInProgress = ref.watch(_orderStatusActionInProgressProvider);
    final oid = orderId ?? '';
    final OrderEntity? live = oid.isNotEmpty ? ref.watch(cookOrderLiveProvider(oid)) : null;
    final OrderEntity? effective = live ?? orderEntity;

    final phase = _cookOrderPhase(effective, orderType);
    final isNew = phase == 'new';
    final isActive = phase == 'active';
    final status = effective?.status;
    final isCancelled = status == OrderStatus.cancelled || status == OrderStatus.rejected;
    debugPrint('[CookOrderDetails] orderId=$orderId, status=$status, phase=$phase (nav=$orderType)');

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildAppBar(context, phase, status),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (effective != null && !isCancelled) ...[
                    _OrderStatusTimelineCook(order: effective),
                    const SizedBox(height: 16),
                  ],
                  if (isCancelled && (effective?.notes ?? '').toString().isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel, color: _C.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order Cancelled',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _C.error,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  effective!.notes ?? '',
                                  style: const TextStyle(fontSize: 13, color: _C.textSub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _section('Order', [
                    _row('Order ID', order['id'] as String),
                    _row('Customer', effective?.customerName ?? order['customer'] as String? ?? '—'),
                    _row('Placed', (order['placed'] as String? ?? order['completedAt'] as String? ?? '—')),
                  ]),
                  _buildItemsSection(ref, effective),
                  _section('Amount', [
                    _row(
                      isNew ? 'Estimated earnings' : 'Total',
                      '${((order['earnings'] ?? order['amount']) as num?)?.toStringAsFixed(2) ?? effective?.totalAmount.toStringAsFixed(2) ?? '0.00'} SAR',
                      valueBold: true,
                      valueColor: _C.success,
                    ),
                  ]),
                  if (isNew || isActive) ...[
                    _section('Time', [
                      _row('Prep time', order['prepTime'] as String? ?? '—'),
                      if (isActive) ...[
                        _row('Ready in', order['readyIn'] as String? ?? '—'),
                        _row('Est. ready', order['estTime'] as String? ?? '—'),
                      ],
                    ]),
                  ],
                  _section('Delivery', [
                    _row('Address', effective?.deliveryAddress ?? order['deliveryAddress'] as String? ?? '—'),
                    _row('Contact', order['contact'] as String? ?? '—'),
                  ]),
                  if (((effective?.notes ?? order['note'])?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBE6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE58F)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note_rounded, size: 18, color: _C.textSub),
                              const SizedBox(width: 6),
                              Text('Customer note', style: TextStyle(fontWeight: FontWeight.w600, color: _C.text, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text((effective?.notes ?? order['note'])?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF8A6914))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (isNew) _buildNewActions(context, ref, actionInProgress),
                  if (isActive && status != null && !isCancelled)
                    _buildActiveActions(context, ref, effective, status, actionInProgress),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String phase, OrderStatus? status) {
    return Container(
      color: _C.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  'Order ${order['id']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              if (phase == 'new')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              if (phase == 'active')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cookStatusAppBarChipColor(status).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _cookStatusAppBarLabel(status),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              if (phase == 'completed')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              if (phase == 'cancelled')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Cancelled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.text)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildItemsSection(WidgetRef ref, OrderEntity? entity) {
    // Prefer in-memory items when provided.
    if (entity != null && entity.items.isNotEmpty) {
      return _section('Items', _buildItemsRows(entity));
    }

    final id = orderId ?? order['id']?.toString();
    if (id == null || id.isEmpty) {
      return _section(
        'Items',
        const [
          Text(
            'No items',
            style: TextStyle(fontSize: 13, color: _C.textSub),
          ),
        ],
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadItemsFromSupabase(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _section(
            'Items',
            const [
              Text(
                'Loading items...',
                style: TextStyle(fontSize: 13, color: _C.textSub),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return _section(
            'Items',
            const [
              Text(
                'Could not load items.',
                style: TextStyle(fontSize: 13, color: _C.textSub),
              ),
            ],
          );
        }

        final data = snapshot.data ?? const <Map<String, dynamic>>[];
        if (data.isEmpty) {
          return _section(
            'Items',
            const [
              Text(
                'No items',
                style: TextStyle(fontSize: 13, color: _C.textSub),
              ),
            ],
          );
        }

        final rows = data.map((item) {
          final name = (item['dish_name'] as String?)?.trim();
          final qtyField = item['quantity'];
          final unitField = item['unit_price'];

          final qty = qtyField is num ? qtyField.toInt() : int.tryParse('$qtyField') ?? 1;
          final unit = unitField is num ? unitField.toDouble() : double.tryParse('$unitField') ?? 0.0;
          final lineTotal = unit * qty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '${qty}x ${name?.isNotEmpty == true ? name : 'Item'}',
                    style: const TextStyle(fontSize: 14, color: _C.text),
                  ),
                ),
                Text(
                  '${unit.toStringAsFixed(2)} SAR',
                  style: const TextStyle(fontSize: 13, color: _C.textSub),
                ),
                const SizedBox(width: 12),
                Text(
                  '${lineTotal.toStringAsFixed(2)} SAR',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.text),
                ),
              ],
            ),
          );
        }).toList();

        return _section('Items', rows);
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadItemsFromSupabase(String id) async {
    try {
      final res = await Supabase.instance.client
          .from('order_items')
          .select('dish_name, quantity, unit_price')
          .eq('order_id', id);
      return (res as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  List<Widget> _buildItemsRows(OrderEntity? entity) {
    if (entity != null && entity.items.isNotEmpty) {
      return [
        ...entity.items.map((item) {
          final lineTotal = item.price * item.quantity;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.quantity}x ${item.dishName}',
                    style: const TextStyle(fontSize: 14, color: _C.text),
                  ),
                ),
                Text(
                  '${item.price.toStringAsFixed(2)} SAR',
                  style: const TextStyle(fontSize: 13, color: _C.textSub),
                ),
                const SizedBox(width: 12),
                Text(
                  '${lineTotal.toStringAsFixed(2)} SAR',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.text),
                ),
              ],
            ),
          );
        }),
      ];
    }
    return [_row('', order['items'] as String? ?? '—')];
  }

  Widget _row(String label, String value, {bool valueBold = false, Color? valueColor}) {
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(value, style: TextStyle(fontSize: 14, color: _C.text, fontWeight: valueBold ? FontWeight.w600 : null)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: _C.textSub))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? _C.text,
                fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewActions(BuildContext context, WidgetRef ref, bool actionInProgress) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: actionInProgress ? null : () async {
              if (orderId == null) return;
              final reason = await showRejectReasonSheet(context);
              if (reason == null) return;
              ref.read(_orderStatusActionInProgressProvider.notifier).state = true;
              try {
                await ref.read(ordersRepositoryProvider).rejectOrder(orderId!, reason: reason);
                if (context.mounted) {
                  SnackbarHelper.success(context, 'Order rejected');
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarHelper.error(context, userFriendlyErrorMessage(e));
                }
              } finally {
                ref.read(_orderStatusActionInProgressProvider.notifier).state = false;
              }
            },
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.error,
              side: const BorderSide(color: _C.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: actionInProgress ? null : () async {
              if (orderId == null) return;
              ref.read(_orderStatusActionInProgressProvider.notifier).state = true;
              try {
                await ref.read(ordersRepositoryProvider).acceptOrder(orderId!);
                if (context.mounted) {
                  SnackbarHelper.success(context, 'Order accepted');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarHelper.error(context, userFriendlyErrorMessage(e));
                }
              } finally {
                ref.read(_orderStatusActionInProgressProvider.notifier).state = false;
              }
            },
            icon: actionInProgress
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(actionInProgress ? 'Please wait...' : 'Accept order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveActions(
    BuildContext context,
    WidgetRef ref,
    OrderEntity? entity,
    OrderStatus status,
    bool actionInProgress,
  ) {
    final oid = orderId ?? '';
    final chatTail = oid.length > 8 ? oid.substring(oid.length - 8) : oid;
    final chatLabel =
        chatTail.isEmpty ? 'Chat with customer' : 'Chat · #$chatTail';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: actionInProgress
                ? null
                : () async {
                    final cid = entity?.customerId;
                    if (cid == null || cid.isEmpty || orderId == null || orderId!.isEmpty) {
                      SnackbarHelper.error(
                        context,
                        'Customer is missing for this order. Chat cannot open.',
                      );
                      return;
                    }
                    try {
                      final chatId =
                          await ref.read(chatRepositoryProvider).getOrCreateConversation(cid);
                      final chefUid = ref.read(authStateProvider).valueOrNull?.id ?? '';
                      final oid = orderId ?? '';
                      if (chefUid.isNotEmpty && oid.isNotEmpty) {
                        await ref.read(customerChatSupabaseDataSourceProvider).tryLinkCustomerChefConversationToOrder(
                              conversationId: chatId,
                              orderId: oid,
                              customerId: cid,
                              chefId: chefUid,
                            );
                      }
                      if (!context.mounted) return;
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CookChatConversationScreen(
                            name: entity?.customerName ?? 'Customer',
                            chatId: chatId,
                            orderId: orderId,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        SnackbarHelper.error(context, userFriendlyErrorMessage(e));
                      }
                    }
                  },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(chatLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.primary,
              side: const BorderSide(color: _C.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: actionInProgress ? null : () async {
              if (orderId == null) return;
              OrderStatus? next;
              if (status == OrderStatus.accepted) {
                next = OrderStatus.preparing;
              } else if (status == OrderStatus.preparing) {
                next = OrderStatus.ready;
              } else if (status == OrderStatus.ready) {
                next = OrderStatus.completed;
              }
              if (next == null) return;
              debugPrint('[CookOrderDetails] Advance status: $status -> $next (orderId=$orderId)');
              ref.read(_orderStatusActionInProgressProvider.notifier).state = true;
              try {
                await ref.read(ordersRepositoryProvider).updateOrderStatus(orderId!, next);
                if (context.mounted) {
                  final message = switch (status) {
                    OrderStatus.accepted => 'Order marked as Preparing',
                    OrderStatus.preparing => 'Order marked as Ready',
                    OrderStatus.ready => 'Order marked as Completed',
                    _ => 'Status updated',
                  };
                  SnackbarHelper.success(context, message);
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarHelper.error(context, userFriendlyErrorMessage(e));
                }
              } finally {
                ref.read(_orderStatusActionInProgressProvider.notifier).state = false;
              }
            },
            icon: actionInProgress
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    status == OrderStatus.accepted
                        ? Icons.local_dining_rounded
                        : status == OrderStatus.preparing
                            ? Icons.check_circle_outline_rounded
                            : Icons.done_all_rounded,
                    size: 18,
                  ),
            label: Text(
              actionInProgress
                  ? 'Please wait...'
                  : status == OrderStatus.accepted
                      ? 'Start Preparing'
                      : status == OrderStatus.preparing
                          ? 'Mark Ready'
                          : 'Complete',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Timeline for cook order details: Order Placed → Accepted → Preparing → Ready → Completed.
class _OrderStatusTimelineCook extends StatelessWidget {
  final OrderEntity order;

  const _OrderStatusTimelineCook({required this.order});

  static const _stepLabels = [
    'Order Placed',
    'Accepted',
    'Preparing',
    'Ready',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    if (status == OrderStatus.cancelled || status == OrderStatus.rejected) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: _C.error.withOpacity(0.9)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'This order was cancelled. Timeline is not shown.',
                  style: TextStyle(fontSize: 13, color: _C.textSub),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentStepIndex = status == OrderStatus.pending
        ? 0
        : status == OrderStatus.accepted
            ? 1
            : status == OrderStatus.preparing
                ? 2
                : status == OrderStatus.ready
                    ? 3
                    : 4;

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
                  color: bothDone ? Colors.green : _C.textSub.withOpacity(0.3),
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
                    color: done
                        ? Colors.green
                        : (current ? Colors.blue : Colors.transparent),
                    border: current || done
                        ? null
                        : Border.all(color: _C.textSub.withOpacity(0.6), width: 2),
                    boxShadow: current
                        ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    _stepLabels[stepIndex],
                    style: TextStyle(
                      fontSize: 9,
                      color: done
                          ? Colors.green
                          : (current ? Colors.blue : _C.textSub),
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
