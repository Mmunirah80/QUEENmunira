import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/naham_theme.dart';
import '../../data/datasources/inspection_datasource.dart';

final inspectionDataSourceProvider = Provider<InspectionDataSource>((ref) => InspectionDataSource());

/// Listens to chefs/{chefId}/inspection_requests/current. When status == pending, shows incoming call dialog.
/// Accept -> join channel and navigate to inspection call screen. Refuse or 30s timeout -> reject + strike.
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
  bool _dialogShown = false;
  Timer? _timeoutTimer;

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
    if (data == null || data['status'] != 'pending') {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      if (_dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _dialogShown = false;
      }
      return;
    }
    if (_dialogShown) return;
    final channelName = data['channelName'] as String?;
    if (channelName == null || !mounted) return;

    _dialogShown = true;
    _timeoutTimer = Timer(const Duration(seconds: 30), () => _onTimeout());

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Inspection call'),
        content: const Text(
          'Admin is requesting a video call to verify hygiene standards. Please respond within 30 seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => _refuse(ctx),
            child: const Text('Reject'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NahamTheme.primary),
            onPressed: () => _accept(ctx, channelName),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext dialogContext, String channelName) async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (!mounted) return;
    Navigator.of(dialogContext).pop();
    _dialogShown = false;

    await ref.read(inspectionDataSourceProvider).acceptRequest(widget.chefId);
    if (!mounted) return;
    context.push(
      RouteNames.chefInspectionCall,
      extra: {'channelName': channelName},
    );
  }

  Future<void> _refuse(BuildContext dialogContext) async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (!mounted) return;
    Navigator.of(dialogContext).pop();
    _dialogShown = false;
    await ref.read(inspectionDataSourceProvider).rejectRequest(widget.chefId);
  }

  void _onTimeout() {
    _timeoutTimer = null;
    if (!_dialogShown || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _dialogShown = false;
    ref.read(inspectionDataSourceProvider).rejectRequest(widget.chefId);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
