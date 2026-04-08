import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/agora_constants.dart';
import '../../inspection_live/inspection_rtc_constants.dart';
import '../../inspection_live/inspection_rtc_helper.dart';
import '../data/models/inspection_outcome.dart';
import '../presentation/providers/admin_providers.dart';
import 'admin_inspection_outcome_screen.dart';

/// Admin joins the inspection channel as a **viewer only** (no local camera).
/// The chef must accept the call and publish video from their device.
class AdminInspectionLiveScreen extends ConsumerStatefulWidget {
  const AdminInspectionLiveScreen({
    super.key,
    required this.callId,
    required this.chefId,
    required this.chefName,
    required this.channelName,
    this.inspectionViolationCountBefore = 0,
  });

  final String callId;
  final String chefId;
  final String chefName;
  final String channelName;
  final int inspectionViolationCountBefore;

  @override
  ConsumerState<AdminInspectionLiveScreen> createState() => _AdminInspectionLiveScreenState();
}

class _AdminInspectionLiveScreenState extends ConsumerState<AdminInspectionLiveScreen> {
  RtcEngine? _engine;
  RtcEngineEventHandler? _handler;
  StreamSubscription<Map<String, dynamic>?>? _callSub;
  String _status = 'pending';
  bool _channelJoined = false;
  bool _remoteVideoReady = false;
  String? _rtcError;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _callSub = ref.read(adminSupabaseDatasourceProvider).watchInspectionCall(widget.callId).listen((row) {
      if (!mounted || row == null) return;
      setState(() => _status = (row['status'] ?? 'pending').toString());
    });
    unawaited(_joinIfPossible());
  }

  Future<void> _joinIfPossible() async {
    if (agoraAppId.isEmpty) {
      if (mounted) setState(() => _channelJoined = true);
      return;
    }
    try {
      final engine = await InspectionRtcHelper.createEngine();
      await InspectionRtcHelper.prepareAdminViewer(engine);
      _handler = RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          if (mounted) setState(() => _channelJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (remoteUid == InspectionRtcConstants.chefUid && mounted) {
            setState(() => _remoteVideoReady = true);
          }
        },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          if (remoteUid == InspectionRtcConstants.chefUid && mounted) {
            if (state == RemoteVideoState.remoteVideoStateDecoding || state == RemoteVideoState.remoteVideoStateStarting) {
              setState(() => _remoteVideoReady = true);
            }
          }
        },
        onError: (ErrorCodeType err, String msg) {
          if (mounted) setState(() => _rtcError = msg);
        },
      );
      await InspectionRtcHelper.joinAdminChannel(
        engine: engine,
        channelName: widget.channelName,
        handler: _handler!,
      );
      _engine = engine;
    } catch (e) {
      if (mounted) setState(() => _rtcError = e.toString());
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final h = _handler;
    final e = _engine;
    if (e != null && h != null) {
      try {
        e.unregisterEventHandler(h);
      } catch (_) {}
    }
    unawaited(InspectionRtcHelper.safeDispose(e));
    super.dispose();
  }

  Future<void> _openOutcome() async {
    final suggested = _suggestedOutcome();
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminInspectionOutcomeScreen(
          callId: widget.callId,
          chefName: widget.chefName,
          inspectionViolationCountBefore: widget.inspectionViolationCountBefore,
          callStatus: _status,
          suggestedOutcome: suggested,
        ),
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  InspectionOutcome? _suggestedOutcome() {
    final s = _status.toLowerCase();
    if (s == 'missed') return InspectionOutcome.noAnswer;
    if (s == 'declined') return InspectionOutcome.refusedInspection;
    return null;
  }

  Future<void> _cancelSession() async {
    try {
      await ref.read(adminSupabaseDatasourceProvider).cancelInspectionCall(widget.callId);
    } catch (e) {
      debugPrint('[AdminInspectionLive] cancel: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _onWillPop() async {
    final go = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave inspection?'),
        content: const Text(
          'Record an outcome, or cancel this session without penalizing the chef.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel session')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'record'), child: const Text('Record outcome')),
        ],
      ),
    );
    if (go == 'record') {
      await _openOutcome();
    } else if (go == 'cancel') {
      await _cancelSession();
    }
  }

  String get _phaseLabel {
    final s = _status.toLowerCase();
    if (s == 'completed') return 'Completed';
    if (s == 'cancelled') return 'Cancelled';
    if (s == 'accepted') {
      if (_remoteVideoReady || agoraAppId.isEmpty) return 'Connected';
      return 'Cook joined — waiting for video';
    }
    if (s == 'pending') return 'Calling cook';
    if (s == 'declined') return 'Cook declined';
    if (s == 'missed') return 'Missed (no answer)';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = _status.toLowerCase();
    final showVideo = agoraAppId.isNotEmpty && _engine != null && st == 'accepted' && _channelJoined;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('Live · ${widget.chefName}'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _onWillPop,
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(
                    _iconForPhase(st),
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _phaseLabel,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_rtcError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _rtcError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            Expanded(
              child: showVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: InspectionRtcConstants.chefUid),
                            connection: RtcConnection(channelId: widget.channelName, localUid: InspectionRtcConstants.adminUid),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Material(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'You are viewing only. The cook controls the camera.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              agoraAppId.isEmpty ? Icons.info_outline : Icons.videocam_outlined,
                              size: 64,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              agoraAppId.isEmpty
                                  ? 'Video is disabled because AGORA_APP_ID is not set. '
                                      'You can still record an outcome. The cook app uses the same channel name when they accept.'
                                  : (st == 'pending'
                                      ? 'Waiting for the cook to accept the inspection on their phone.'
                                      : (st == 'declined'
                                          ? 'The cook declined this inspection. Record an outcome (for example Refused inspection).'
                                          : (st == 'missed'
                                              ? 'The cook did not answer in time. Record an outcome (for example No answer).'
                                              : (st == 'accepted'
                                                  ? 'Joining video…'
                                                  : 'Use Record outcome when the session should end.')))),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _openOutcome,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Record outcome'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForPhase(String st) {
    if (st == 'accepted') return Icons.link_rounded;
    if (st == 'pending') return Icons.phone_in_talk_rounded;
    if (st == 'declined' || st == 'missed') return Icons.phone_missed_rounded;
    return Icons.info_outline;
  }
}
