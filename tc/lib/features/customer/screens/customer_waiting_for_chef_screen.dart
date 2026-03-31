// ============================================================
// WAITING FOR CHEF — 5-min timer, realtime order status (customer cancel disabled).
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_order_details_screen.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';
import 'package:naham_cook_app/features/orders/presentation/orders_failure.dart';
import 'package:naham_cook_app/features/orders/presentation/widgets/orders_stream_error_panel.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const text = AppDesignSystem.textPrimary;
}

const _waitSeconds = 5 * 60; // 5 minutes

class CustomerWaitingForChefScreen extends ConsumerStatefulWidget {
  final String orderId;

  const CustomerWaitingForChefScreen({super.key, required this.orderId});

  @override
  ConsumerState<CustomerWaitingForChefScreen> createState() => _CustomerWaitingForChefScreenState();
}

class _CustomerWaitingForChefScreenState extends ConsumerState<CustomerWaitingForChefScreen> {
  int _remainingSeconds = _waitSeconds;
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        await _onExpired();
        return;
      }

      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _onExpired() async {
    if (_timedOut) return;
    setState(() => _timedOut = true);
    try {
      await ref.read(customerOrdersSupabaseDatasourceProvider).expireOrderByTimeout(widget.orderId);
    } catch (e) {
      debugPrint('[WaitingForChef] Expire order error: $e');
      if (mounted) {
        SnackbarHelper.error(context, resolveOrdersUiError(e));
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order expired')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(customerOrderByIdStreamProvider(widget.orderId));

    return orderAsync.when(
      data: (order) {
        if (order != null && order.status == OrderStatus.cancelled) {
          _timer?.cancel();
          final notes = (order.notes ?? '').toLowerCase();
          final isSoldOut =
              notes.contains('sold out') || notes.contains('sold-out') || notes.contains('unavailable') || notes.contains('no longer');
          final message = isSoldOut
              ? 'Sorry, this dish is no longer available'
              : 'Order cancelled';

          return Scaffold(
            backgroundColor: _C.bg,
            appBar: AppBar(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              title: const Text('Order Status'),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 72, color: _C.primary.withValues(alpha: 0.7)),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (order != null && order.status == OrderStatus.accepted) {
          _timer?.cancel();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => CustomerOrderDetailsScreen(orderId: widget.orderId),
              ),
            );
          });
          return Scaffold(
            backgroundColor: _C.bg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: _C.primary),
                  const SizedBox(height: 16),
                  Text('Order accepted! Redirecting...', style: TextStyle(fontSize: 16, color: _C.text)),
                ],
              ),
            ),
          );
        }

        return _buildWaitingBody();
      },
      loading: () => Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.primary,
          foregroundColor: Colors.white,
          title: const Text('Waiting for Cook'),
        ),
        body: const Center(child: CircularProgressIndicator(color: _C.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.primary,
          foregroundColor: Colors.white,
          title: const Text('Waiting for Cook'),
        ),
        body: Center(
          child: OrdersStreamErrorPanel(
            error: e,
            onRetry: () => ref.invalidate(customerOrderByIdStreamProvider(widget.orderId)),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingBody() {
    final min = _remainingSeconds ~/ 60;
    final sec = _remainingSeconds % 60;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        title: const Text('Waiting for Cook'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, size: 80, color: _C.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 24),
              const Text(
                'Waiting for cook to accept your order...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _C.text),
              ),
              const SizedBox(height: 12),
              Text(
                "Pickup only. After acceptance you'll see the order timeline and can chat with the cook (e.g. share a Google Maps pin).",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _C.text.withValues(alpha: 0.75), height: 1.35),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: _C.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
