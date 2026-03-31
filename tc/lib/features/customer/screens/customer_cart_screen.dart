// ============================================================
// CUSTOMER CART — Add/remove, quantities, subtotal + 10% commission, checkout to Payment.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/supabase/supabase_config.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/customer/data/models/cart_item_model.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_payment_screen.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

const double _commissionRate = 0.10;

class NahamCustomerCartScreen extends ConsumerStatefulWidget {
  const NahamCustomerCartScreen({super.key});

  @override
  ConsumerState<NahamCustomerCartScreen> createState() => _NahamCustomerCartScreenState();
}

class _NahamCustomerCartScreenState extends ConsumerState<NahamCustomerCartScreen> {
  bool _didClampOnce = false;

  Future<int> _fetchRemainingQuantity(String dishId) async {
    final row = await SupabaseConfig.client
        .from('menu_items')
        .select('remaining_quantity')
        .eq('id', dishId)
        .maybeSingle();
    return (row?['remaining_quantity'] as num?)?.toInt() ?? 0;
  }

  Future<void> _clampCartToRemaining(List<CartItemModel> cart) async {
    for (final item in cart) {
      final remaining = await _fetchRemainingQuantity(item.dishId);
      print('[QuantityCheck][CartClamp] dishId=${item.dishId} chefId=${item.chefId} cartQty=${item.quantity} remaining=$remaining');

      if (remaining <= 0) {
        ref.read(cartProvider.notifier).updateQuantity(item.dishId, item.chefId, 0);
        continue;
      }

      if (item.quantity > remaining) {
        ref.read(cartProvider.notifier).updateQuantity(item.dishId, item.chefId, remaining);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_didClampOnce) return;
      final cart = ref.read(cartProvider);
      if (cart.isEmpty) return;
      _didClampOnce = true;
      await _clampCartToRemaining(cart);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final pickupOrigin = ref.watch(customerPickupOriginProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final commission = subtotal * _commissionRate;
    final total = subtotal + commission;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        title: const Text('Cart'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: cart.isEmpty
          ? _EmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    itemBuilder: (_, i) {
                      final item = cart[i];
                      return _CartItemTile(
                        item: item,
                        onRemove: () => ref.read(cartProvider.notifier).remove(item.dishId, item.chefId),
                        onQuantity: (q) async {
                          // Decrement is always safe.
                          if (q <= item.quantity) {
                            ref.read(cartProvider.notifier).updateQuantity(item.dishId, item.chefId, q);
                            return;
                          }

                          final remaining = await _fetchRemainingQuantity(item.dishId);
                          print('[QuantityCheck][CartPlus] dishId=${item.dishId} chefId=${item.chefId} newQty=$q remaining=$remaining');

                          if (remaining <= 0) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This dish is sold out'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (q > remaining) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Only $remaining available'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          ref.read(cartProvider.notifier).updateQuantity(item.dishId, item.chefId, q);
                        },
                      );
                    },
                  ),
                ),
                _CartSummary(
                  subtotal: subtotal,
                  commission: commission,
                  total: total,
                  onCheckout: () {
                    if (pickupOrigin == null) {
                      SnackbarHelper.error(
                        context,
                        'Set your pickup point on Home (GPS or map) before checkout. Pickup only — no delivery.',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const CustomerPaymentScreen()),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: AppDesignSystem.primaryLight),
          const SizedBox(height: 16),
          const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.text)),
          const SizedBox(height: 8),
          const Text('Add dishes from Home or Search', style: TextStyle(color: _C.textSub)),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback onRemove;
  final Future<void> Function(int) onQuantity;

  const _CartItemTile({required this.item, required this.onRemove, required this.onQuantity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.dishName, style: const TextStyle(fontWeight: FontWeight.w700, color: _C.text)),
                  Text(item.chefName, style: const TextStyle(fontSize: 12, color: _C.textSub)),
                  Text('${item.price.toStringAsFixed(0)} SAR', style: const TextStyle(fontSize: 12, color: _C.primary)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async => onQuantity(item.quantity - 1),
                  color: _C.primary,
                ),
                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async => onQuantity(item.quantity + 1),
                  color: _C.primary,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppDesignSystem.errorRed),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double subtotal;
  final double commission;
  final double total;
  final VoidCallback onCheckout;

  const _CartSummary({
    required this.subtotal,
    required this.commission,
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Row('Subtotal', subtotal),
            _Row('Commission (10%)', commission),
            const Divider(),
            _Row('Total', total, bold: true),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _Row(this.label, this.value, {this.bold = false});

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
