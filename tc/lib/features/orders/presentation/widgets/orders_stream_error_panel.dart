import 'package:flutter/material.dart';

import '../orders_failure.dart';

/// Full-width error state for order streams: offline, auth, rate limit, generic.
/// Debounces retry taps to avoid duplicate invalidations under stress.
class OrdersStreamErrorPanel extends StatefulWidget {
  const OrdersStreamErrorPanel({
    super.key,
    required this.error,
    required this.onRetry,
    this.padding = const EdgeInsets.all(24),
  });

  final Object error;
  final VoidCallback onRetry;
  final EdgeInsets padding;

  @override
  State<OrdersStreamErrorPanel> createState() => _OrdersStreamErrorPanelState();
}

class _OrdersStreamErrorPanelState extends State<OrdersStreamErrorPanel> {
  static const _debounce = Duration(milliseconds: 500);
  bool _retryBusy = false;

  void _scheduleRetry() {
    if (_retryBusy) return;
    setState(() => _retryBusy = true);
    widget.onRetry();
    Future<void>.delayed(_debounce, () {
      if (mounted) setState(() => _retryBusy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final offline = ordersErrorIsOffline(widget.error);
    final auth = ordersErrorIsAuth(widget.error);
    final rate = ordersErrorIsRateLimit(widget.error);
    final icon = offline
        ? Icons.wifi_off_rounded
        : auth
            ? Icons.lock_outline_rounded
            : rate
                ? Icons.hourglass_top_rounded
                : Icons.error_outline_rounded;

    return SingleChildScrollView(
      child: Padding(
        padding: widget.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: offline
                  ? 'No network connection'
                  : auth
                      ? 'Session or permission error'
                      : 'Something went wrong loading orders',
              child: Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              resolveOrdersUiError(widget.error),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Retry',
              child: FilledButton.icon(
                onPressed: _retryBusy ? null : _scheduleRetry,
                icon: _retryBusy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: Text(_retryBusy ? 'Retrying…' : 'Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
