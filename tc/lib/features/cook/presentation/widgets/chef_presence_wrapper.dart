import 'package:flutter/material.dart';

/// Presence wrapper (no-op).
///
/// IMPORTANT: We intentionally do NOT auto-write is_online based on lifecycle
/// to avoid rebuild/write loops on Flutter web.
class ChefPresenceWrapper extends StatefulWidget {
  final String chefId;
  final String? name;
  final Widget child;

  const ChefPresenceWrapper({
    super.key,
    required this.chefId,
    this.name,
    required this.child,
  });

  @override
  State<ChefPresenceWrapper> createState() => _ChefPresenceWrapperState();
}

class _ChefPresenceWrapperState extends State<ChefPresenceWrapper> {
  @override
  Widget build(BuildContext context) => widget.child;
}
