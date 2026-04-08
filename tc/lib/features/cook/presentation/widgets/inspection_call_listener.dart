import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/inspection_datasource.dart';
import '../../screens/chef_incoming_inspection_screen.dart';
import '../../screens/chef_inspection_result_screen.dart';

/// Subscribes to [inspection_calls] for this chef: pending → incoming full screen; completed → result screen.
class InspectionCallListener extends ConsumerStatefulWidget {
  final String chefId;
  final Widget child;
  /// When false, no inspection subscription (pending approval / suspended).
  final bool enabled;

  const InspectionCallListener({
    super.key,
    required this.chefId,
    required this.child,
    this.enabled = true,
  });

  @override
  ConsumerState<InspectionCallListener> createState() => _InspectionCallListenerState();
}

class _InspectionCallListenerState extends ConsumerState<InspectionCallListener> {
  StreamSubscription<Map<String, dynamic>?>? _sub;
  bool _incomingOpen = false;
  String? _lastResultCallId;

  void _attachIfNeeded() {
    _sub?.cancel();
    _sub = null;
    if (!widget.enabled) return;
    _sub = ref.read(inspectionDataSourceProvider).watchCurrentRequest(widget.chefId).listen(_onRequest);
  }

  @override
  void initState() {
    super.initState();
    _attachIfNeeded();
  }

  @override
  void didUpdateWidget(covariant InspectionCallListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled || oldWidget.chefId != widget.chefId) {
      _attachIfNeeded();
    }
  }

  void _onRequest(Map<String, dynamic>? data) {
    if (data == null) {
      return;
    }

    final status = (data['status'] ?? '').toString();

    if (status == 'completed') {
      unawaited(_showResultIfNeeded(data));
      return;
    }

    if (status != 'pending') {
      return;
    }

    if (_incomingOpen) return;
    final channelName = data['channelName'] as String?;
    final callId = (data['id'] ?? '').toString();
    if (channelName == null || channelName.isEmpty || callId.isEmpty || !mounted) return;

    _incomingOpen = true;
    unawaited(
      Navigator.of(context, rootNavigator: true)
          .push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChefIncomingInspectionScreen(
            callId: callId,
            channelName: channelName,
            chefId: widget.chefId,
          ),
          fullscreenDialog: true,
        ),
      )
          .then((_) {
        _incomingOpen = false;
      }),
    );
  }

  Future<void> _showResultIfNeeded(Map<String, dynamic> data) async {
    final callId = (data['id'] ?? '').toString();
    if (callId.isEmpty || callId == _lastResultCallId) return;
    final alreadySeen = data['chefResultSeen'] == true;
    if (alreadySeen) return;

    final action = (data['resultAction'] ?? '').toString();
    final outcome = (data['outcome'] ?? '').toString();
    if (action.isEmpty && outcome.isEmpty) return;

    _lastResultCallId = callId;
    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChefInspectionResultScreen(
          outcome: outcome,
          resultAction: action,
          resultNote: data['resultNote']?.toString(),
          violationReason: data['violationReason']?.toString(),
        ),
        fullscreenDialog: true,
      ),
    );
    await ref.read(inspectionDataSourceProvider).markResultSeen(callId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
