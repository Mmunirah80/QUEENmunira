import 'dart:async';

import 'package:flutter/material.dart';

import 'package:naham_cook_app/core/orders/order_pending_timeout.dart';

/// Live MM:SS until chef must accept (from [orders.created_at] + [kChefAcceptanceTimeout]).
/// Use on order cards while status is pending.
class PendingChefResponseCountdown extends StatefulWidget {
  final DateTime createdAtUtc;
  final Color strongColor;
  final Color mutedColor;

  const PendingChefResponseCountdown({
    super.key,
    required this.createdAtUtc,
    required this.strongColor,
    required this.mutedColor,
  });

  @override
  State<PendingChefResponseCountdown> createState() => _PendingChefResponseCountdownState();
}

class _PendingChefResponseCountdownState extends State<PendingChefResponseCountdown> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant PendingChefResponseCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.createdAtUtc != widget.createdAtUtc) {
      _tick();
    }
  }

  void _tick() {
    if (!mounted) return;
    final rem = remainingAcceptanceSeconds(widget.createdAtUtc, DateTime.now().toUtc());
    setState(() => _remainingSeconds = rem);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) {
      return Text(
        'Awaiting cook response…',
        style: TextStyle(fontSize: 12, color: widget.mutedColor, fontWeight: FontWeight.w500),
      );
    }
    final min = _remainingSeconds ~/ 60;
    final sec = _remainingSeconds % 60;
    return Text(
      'Cook must respond in ${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: widget.strongColor,
      ),
    );
  }
}
