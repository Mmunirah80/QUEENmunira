import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/admin/screens/admin_monitor_chats_screen.dart';
import 'package:naham_cook_app/features/orders/presentation/orders_failure.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';

/// Admin: browse all customer/chef orders and open read-only detail (RLS admin SELECT).
class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  static String _formatMoney(dynamic v) {
    if (v is num) return v.toDouble().toStringAsFixed(2);
    if (v is String) return double.tryParse(v)?.toStringAsFixed(2) ?? v;
    return '0.00';
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  /// Maps DB `orders.status` to a short monitoring label.
  static String _statusLabel(String raw) {
    final r = raw.trim();
    if (r == 'paid_waiting_acceptance') return 'Paid · awaiting cook';
    final d = OrderDbStatus.domainFromDb(r);
    return switch (d) {
      OrderStatus.pending => 'Pending',
      OrderStatus.accepted => 'Accepted',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready for pickup',
      OrderStatus.completed => 'Completed',
      OrderStatus.rejected => 'Rejected',
      OrderStatus.cancelled => switch (r) {
        'cancelled_by_customer' => 'Cancelled (customer)',
        'cancelled_by_cook' => 'Cancelled (cook)',
        'cancelled_payment_failed' => 'Payment failed',
        'expired' => 'Expired',
        _ => 'Cancelled',
      },
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final async = ref.watch(adminOrdersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminOrdersListProvider),
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
            return const Center(child: Text('No orders yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              final id = (r['id'] ?? '').toString();
              final customer = (r['customer_name'] ?? r['customer_id'] ?? '—').toString();
              final chef = (r['chef_name'] ?? r['chef_id'] ?? '—').toString();
              final statusRaw = (r['status'] ?? '').toString();
              final status = _statusLabel(statusRaw);
              final total = _formatMoney(r['total_amount']);
              final created = (r['created_at'] ?? '').toString();
              return Card(
                child: ListTile(
                  title: Text(
                    '#${_shortId(id)} · $status',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '$customer → $chef\n$created · SAR $total',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: id.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminOrderDetailScreen(orderId: id),
                            ),
                          );
                        },
                ),
              );
            },
          );
        },
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
        title: const Text('Order detail'),
        actions: [
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Order $id', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _kv(
                'Status',
                AdminOrdersScreen._statusLabel((order['status'] ?? '').toString()),
              ),
              _kv('Customer', (order['customer_name'] ?? order['customer_id'] ?? '—').toString()),
              _kv('Chef', (order['chef_name'] ?? order['chef_id'] ?? '—').toString()),
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
              _AdminOrderChatCta(orderId: id),
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

class _AdminOrderChatCta extends ConsumerWidget {
  const _AdminOrderChatCta({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOrderConversationIdProvider(orderId));
    return async.when(
      data: (cid) {
        if (cid == null || cid.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'No per-order chat linked (legacy thread or migration not applied).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: FilledButton.icon(
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Open order chat (monitor)'),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AdminMonitorConversationScreen(
                    chatId: cid,
                    title: 'Order ${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
