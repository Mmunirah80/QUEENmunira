import 'package:flutter/material.dart';

/// Visual press feedback: scales child down on pointer down.
///
/// This is intentionally visual-only: it does not prevent the child widget
/// from receiving taps/gestures.
class PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double pressedScale;
  final Duration duration;

  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

