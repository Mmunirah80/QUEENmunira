import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/agora_constants.dart';
import '../../../core/theme/naham_theme.dart';

/// Chef joins the inspection Agora channel when they accept the call.
class InspectionCallScreen extends StatefulWidget {
  final String channelName;

  const InspectionCallScreen({super.key, required this.channelName});

  @override
  State<InspectionCallScreen> createState() => _InspectionCallScreenState();
}

class _InspectionCallScreenState extends State<InspectionCallScreen> {
  RtcEngine? _engine;
  bool _isConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _joinChannel();
  }

  Future<void> _joinChannel() async {
    if (agoraAppId.isEmpty) {
      if (mounted) setState(() => _isConnected = true);
      return;
    }
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        const RtcEngineContext(
          appId: agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (mounted) setState(() => _isConnected = true);
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            if (mounted) setState(() => _isConnected = false);
          },
        ),
      );
      await _engine!.joinChannel(
        token: '',
        channelId: widget.channelName,
        uid: 1,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isConnected = false;
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: NahamTheme.headerBackground,
        foregroundColor: Colors.white,
        title: const Text('Inspection call'),
      ),
      body: SafeArea(
        child: Center(
          child: _error != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.white70)),
                  ],
                )
              : _isConnected
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_rounded, size: 80, color: NahamTheme.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'Connected. Admin is viewing.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: NahamTheme.primary),
                        SizedBox(height: 16),
                        Text('Connecting...', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () => context.pop(),
        child: const Icon(Icons.call_end_rounded),
      ),
    );
  }
}
