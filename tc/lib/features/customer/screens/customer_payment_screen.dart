// ============================================================
// PAYMENT — Order summary from cart, address, Place Order → create order in Supabase → Waiting screen.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/features/orders/presentation/orders_failure.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:naham_cook_app/features/customer/data/models/cart_item_model.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_main_navigation_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_order_details_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_waiting_for_chef_screen.dart';
import 'package:naham_cook_app/features/customer/widgets/press_scale.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

const double _commissionRate = 0.10;

class CustomerPaymentScreen extends ConsumerStatefulWidget {
  const CustomerPaymentScreen({super.key});

  @override
  ConsumerState<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends ConsumerState<CustomerPaymentScreen> {
  bool _loading = false;
  // Keeps per-order-group idempotency keys across retries during this checkout session.
  final Map<String, String> _pendingIdempotencyKeysByGroup = {};
  static const _pendingIdempotencyStorageKey = 'customer_payment_pending_idempotency_keys_v1';

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final commission = subtotal * _commissionRate;
    final total = subtotal + commission;
    final addresses = ref.watch(customerAddressesStreamProvider).valueOrNull ?? [];
    final pickup = ref.watch(customerPickupOriginProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final customerName = user?.name ?? user?.email ?? 'Test Customer';

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.primary,
          foregroundColor: Colors.white,
          title: const Text('Payment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Your cart is empty. Add items from Home to checkout.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final savedProfileAddress = _formatAddress(addresses.isNotEmpty ? addresses.first : null);
    final meetupForOrder = _meetupStringForOrder(pickup: pickup, savedProfileAddress: savedProfileAddress);
    final meetupDisplay = _meetupDisplayLines(
      pickup: pickup,
      savedProfileAddress: savedProfileAddress,
    );

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Order summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text)),
                  const SizedBox(height: 12),
                  ...cart.map((item) => _SummaryRow(
                        label: '${item.dishName} × ${item.quantity}',
                        value: item.lineTotal,
                      )),
                  const SizedBox(height: 16),
                  _SummaryRow(label: 'Subtotal', value: subtotal),
                  _SummaryRow(label: 'Commission (10%)', value: commission),
                  const Divider(height: 24),
                  _SummaryRow(label: 'Total', value: total, bold: true),
                  const SizedBox(height: 24),
                  const Text('Pickup / meet point', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.text)),
                  const SizedBox(height: 4),
                  Text(
                    pickup != null
                        ? 'From Home: GPS or map pin you set (stored on this device). Exact spot with the cook can be shared in chat.'
                        : (savedProfileAddress.isNotEmpty
                            ? 'No pickup pin on Home — using saved profile address if you place order.'
                            : 'Set pickup on Home (recommended), or add an address in Profile.'),
                    style: const TextStyle(fontSize: 12, color: _C.textSub, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Text(
                      meetupDisplay,
                      style: const TextStyle(color: _C.textSub, fontSize: 14, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PressScale(
                    enabled: !_loading,
                    child: FilledButton(
                      onPressed: _loading ? null : () => _payNow(context, ref, cart, customerName, meetupForOrder, total),
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Place Order'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatAddress(Map<String, dynamic>? a) {
    if (a == null) return '';
    final street = a['street'] as String? ?? '';
    final city = a['city'] as String? ?? '';
    final label = a['label'] as String? ?? '';
    final parts = [if (label.isNotEmpty) label, street, if (city.isNotEmpty) city];
    return parts.join(', ');
  }

  /// Single string stored on the order (pickup-first; cook can open coords in Maps).
  static String _meetupStringForOrder({
    required CustomerPickupOrigin? pickup,
    required String savedProfileAddress,
  }) {
    if (pickup != null) {
      final lat = pickup.latitude.toStringAsFixed(5);
      final lng = pickup.longitude.toStringAsFixed(5);
      final area = pickup.detailLabel.trim();
      final areaBit = area.isNotEmpty ? ' · $area' : '';
      return 'Pickup: ${pickup.label}$areaBit ($lat, $lng)';
    }
    return savedProfileAddress.trim();
  }

  static String _meetupDisplayLines({
    required CustomerPickupOrigin? pickup,
    required String savedProfileAddress,
  }) {
    if (pickup != null) {
      final lat = pickup.latitude.toStringAsFixed(5);
      final lng = pickup.longitude.toStringAsFixed(5);
      final buf = StringBuffer(pickup.headerLine);
      if (pickup.label.trim().isNotEmpty && pickup.headerLine.trim() != pickup.label.trim()) {
        buf.write('\n${pickup.label}');
      }
      buf.write('\n$lat, $lng');
      if (savedProfileAddress.isNotEmpty) {
        buf.write('\n\nOptional profile address:\n$savedProfileAddress');
      }
      return buf.toString();
    }
    if (savedProfileAddress.isNotEmpty) {
      return savedProfileAddress;
    }
    return 'Not set — open Home and use “Use my current location” or “Pick on map”,\nor add an address under Profile → Addresses.';
  }

  Future<void> _payNow(
    BuildContext context,
    WidgetRef ref,
    List<CartItemModel> cart,
    String customerName,
    String meetupForOrder,
    double totalWithCommission,
  ) async {
    // Hard lock for rapid taps / re-entrancy.
    if (_loading) return;
    final customerId = ref.read(customerIdProvider);
    if (kDebugMode) {
      debugPrint(
        '[Payment] placeOrder tapped customerId=$customerId empty=${customerId.isEmpty}',
      );
    }
    if (customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to place an order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (meetupForOrder.trim().isEmpty) {
      SnackbarHelper.error(
        context,
        'Set a pickup point on Home (GPS or map), or add an address in Profile → Addresses.',
      );
      return;
    }

    debugPrint('[Payment] Starting _payNow with customerId=$customerId, itemsInCart=${cart.length}, totalWithCommission=$totalWithCommission');
    await _loadPendingIdempotencyKeys();
    setState(() => _loading = true);

    final ds = ref.read(customerOrdersSupabaseDatasourceProvider);
    final groups = <String, List<CartItemModel>>{};
    for (final item in cart) {
      groups.putIfAbsent(item.chefId, () => []).add(item);
    }
    final activeGroupSignatures = <String>{};
    if (kDebugMode) {
      debugPrint('[Payment] cart groups (chefs): ${groups.length}');
    }

    final orderIds = <String>[];
    try {
      for (final entry in groups.entries) {
        final chefId = entry.key;
        final items = entry.value;
        final chefName = items.first.chefName;
        final signature = _buildOrderGroupSignature(
          customerId: customerId,
          chefId: chefId,
          items: items,
          meetupForOrder: meetupForOrder,
        );
        activeGroupSignatures.add(signature);
        final idempotencyKey = _pendingIdempotencyKeysByGroup.putIfAbsent(
          signature,
          () => const Uuid().v4(),
        );
        await _savePendingIdempotencyKeys();
        if (kDebugMode) {
          debugPrint(
            '[Payment] idempotencyKey=$idempotencyKey chef=$chefId items=${items.length}',
          );
        }
        final groupSubtotal = items.fold<double>(0, (s, e) => s + e.lineTotal);
        final groupCommission = groupSubtotal * _commissionRate;
        final groupTotal = groupSubtotal + groupCommission;
        if (kDebugMode) {
          debugPrint(
            '[Payment] subtotal=$groupSubtotal commission=$groupCommission total=$groupTotal',
          );
        }
        final itemsPayload = items
            .map((e) => {
                  'id': e.dishId,
                  'dishName': e.dishName,
                  'quantity': e.quantity,
                  'price': e.price,
                })
            .toList();
        debugPrint(
          '[Payment] Creating order chef=$chefId total=$groupTotal items=${itemsPayload.length}',
        );
        if (kDebugMode) {
          debugPrint('[Payment] itemsPayload: $itemsPayload');
        }

        final id = await ds.createOrder(
          customerId: customerId,
          customerName: customerName,
          chefId: chefId,
          chefName: chefName,
          idempotencyKey: idempotencyKey,
          items: itemsPayload,
          totalAmount: groupTotal,
          commissionAmount: groupCommission,
          deliveryAddress: meetupForOrder.isEmpty ? null : meetupForOrder,
        );
        orderIds.add(id);
        debugPrint('[Payment] order created id=$id');
      }

      ref.read(cartProvider.notifier).clear();
      _pendingIdempotencyKeysByGroup.clear();
      await _savePendingIdempotencyKeys();
      if (kDebugMode) debugPrint('[Payment] cart cleared, navigating to waiting');

      if (context.mounted) {
        setState(() => _loading = false);
        SnackbarHelper.success(context, 'Order placed successfully');
        if (orderIds.length == 1) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => CustomerWaitingForChefScreen(orderId: orderIds.first),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => _CreatedOrdersSummaryScreen(orderIds: orderIds),
            ),
          );
        }
      }
    } catch (e, st) {
      // Keep idempotency keys for active groups so a retry can reuse them.
      _pendingIdempotencyKeysByGroup.removeWhere(
        (signature, _) => !activeGroupSignatures.contains(signature),
      );
      await _savePendingIdempotencyKeys();
      if (!mounted || !context.mounted) return;
      setState(() => _loading = false);
      if (kDebugMode) {
        debugPrint('[Payment] error=$e');
        debugPrint('[Payment] stackTrace: $st');
        if (e is PostgrestException) {
          debugPrint('[Payment] Postgrest code=${e.code} message=${e.message}');
        }
      }
      final msg = resolveOrdersUiError(
        e,
        fallback: 'Could not place order. Please check your connection and try again.',
      );
      SnackbarHelper.error(context, msg);
    }
  }

  String _buildOrderGroupSignature({
    required String customerId,
    required String chefId,
    required List<CartItemModel> items,
    required String meetupForOrder,
  }) {
    final normalized = items
        .map((e) => '${e.dishId}|${e.quantity}|${e.price.toStringAsFixed(2)}')
        .toList()
      ..sort();
    final meetup = meetupForOrder.trim();
    return '$customerId::$chefId::$meetup::${normalized.join(',')}';
  }

  Future<void> _loadPendingIdempotencyKeys() async {
    if (_pendingIdempotencyKeysByGroup.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = prefs.getStringList(_pendingIdempotencyStorageKey) ?? const <String>[];
      for (final row in rows) {
        final i = row.indexOf('||');
        if (i <= 0) continue;
        final signature = row.substring(0, i);
        final key = row.substring(i + 2);
        if (signature.isEmpty || key.isEmpty) continue;
        _pendingIdempotencyKeysByGroup[signature] = key;
      }
    } catch (_) {
      // Non-fatal: fallback to in-memory map for this session.
    }
  }

  Future<void> _savePendingIdempotencyKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingIdempotencyKeysByGroup.isEmpty) {
        await prefs.remove(_pendingIdempotencyStorageKey);
        return;
      }
      final rows = _pendingIdempotencyKeysByGroup.entries
          .map((e) => '${e.key}||${e.value}')
          .toList();
      await prefs.setStringList(_pendingIdempotencyStorageKey, rows);
    } catch (_) {
      // Non-fatal.
    }
  }
}

class _CreatedOrdersSummaryScreen extends StatelessWidget {
  final List<String> orderIds;

  const _CreatedOrdersSummaryScreen({required this.orderIds});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        title: const Text('Orders Placed'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => CustomerMainNavigationScreen(
                        initialIndex: 3,
                        newlyPlacedOrderIds: orderIds,
                      ),
                    ),
                    (route) => route.isFirst,
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Track all orders'),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orderIds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final id = orderIds[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text('#${id.substring(0, id.length >= 8 ? 8 : id.length)}'),
                  subtitle: const Text('Tap to track this order'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerOrderDetailsScreen(orderId: id),
                      ),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _SummaryRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: _C.text)),
          Text('${value.toStringAsFixed(1)} SAR', style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: _C.primary)),
        ],
      ),
    );
  }
}
