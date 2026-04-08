// ============================================================
// WAITING FOR CHEF — Countdown from [orders.created_at] + 5 min (same as backend).
// Realtime order stream; expiry also enforced server-side (see supabase_orders_pending_timeout_v1.sql).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/orders/order_pending_timeout.dart';
import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_order_details_screen.dart';
import 'package:naham_cook_app/features/orders/data/models/order_model.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';
import 'package:naham_cook_app/features/orders/presentation/mappers/order_ui_mapper.dart';
import 'package:naham_cook_app/features/orders/presentation/orders_failure.dart';
import 'package:naham_cook_app/features/orders/presentation/widgets/orders_stream_error_panel.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const text = AppDesignSystem.textPrimary;
}

class CustomerWaitingForChefScreen extends ConsumerStatefulWidget {
  final String orderId;

  const CustomerWaitingForChefScreen({super.key, required this.orderId});

  @override
  ConsumerState<CustomerWaitingForChefScreen> createState() => _CustomerWaitingForChefScreenState();
}

class _CustomerWaitingForChefScreenState extends ConsumerState<CustomerWaitingForChefScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _expireCallInFlight = false;
  String? _timerSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final order = ref.read(customerOrderByIdStreamProvider(widget.orderId)).valueOrNull;
      if (order != null && order.status == OrderStatus.pending) {
        _ensureTimerForOrder(order);
      }
    }
  }

  void _ensureTimerForOrder(OrderModel order) {
    final sig = '${order.id}:${order.createdAt.toUtc().toIso8601String()}';
    if (_timerSignature == sig && _timer != null) return;
    _timerSignature = sig;
    _timer?.cancel();
    void tick() {
      if (!mounted) return;
      final now = DateTime.now().toUtc();
      final rem = remainingAcceptanceSeconds(order.createdAt, now);
      setState(() => _remainingSeconds = rem);
      if (rem <= 0) {
        _timer?.cancel();
        unawaited(_onDeadlineReached());
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _onDeadlineReached() async {
    if (_expireCallInFlight) return;
    final latest = ref.read(customerOrderByIdStreamProvider(widget.orderId)).valueOrNull;
    if (latest == null || latest.status != OrderStatus.pending) return;

    _expireCallInFlight = true;
    var success = false;
    try {
      await ref.read(customerOrdersSupabaseDatasourceProvider).expireOrderByTimeout(widget.orderId);
      success = true;
    } catch (e, st) {
      debugPrint('[WaitingForChef] Expire order error: $e\n$st');
      if (mounted) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('not allowed') && !msg.contains('updated by another')) {
          SnackbarHelper.error(context, resolveOrdersUiError(e));
        }
      }
    } finally {
      _expireCallInFlight = false;
    }

    if (!mounted) return;
    ref.invalidate(customerOrderByIdStreamProvider(widget.orderId));
    if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelled by system')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(customerOrderByIdStreamProvider(widget.orderId));

    return orderAsync.when(
      data: (order) {
        if (order == null) {
          return Scaffold(
            backgroundColor: _C.bg,
            appBar: AppBar(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              title: const Text('Waiting for Cook'),
            ),
            body: const Center(child: CircularProgressIndicator(color: _C.primary)),
          );
        }

        if (order.status == OrderStatus.cancelled) {
          _timer?.cancel();
          final notes = (order.notes ?? '').toLowerCase();
          final isSoldOut = notes.contains('sold out') ||
              notes.contains('sold-out') ||
              notes.contains('unavailable') ||
              notes.contains('no longer');
          final message = isSoldOut
              ? 'Sorry, this dish is no longer available'
              : OrderDbStatus.customerCancellationSummary(
                  order.dbStatus,
                  cancelReason: order.cancelReason,
                  orderStatusFallback: order.status,
                );

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

        if (order.status == OrderStatus.accepted) {
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

        if (order.status == OrderStatus.pending) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureTimerForOrder(order);
          });
        }

        return _buildWaitingBody(order);
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

  Widget _buildWaitingBody(OrderModel order) {
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
              if (widget.orderId.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Order #${OrderUiMapper.shortOrderId(widget.orderId)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.primary),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  widget.orderId,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _C.text.withValues(alpha: 0.75), height: 1.3),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                "Pickup only. After acceptance you'll see the order timeline and can chat with the cook (e.g. share a Google Maps pin).",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _C.text.withValues(alpha: 0.75), height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                'Chef has ${kChefAcceptanceTimeout.inMinutes} minutes to respond',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _C.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
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
