import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/agora_constants.dart';
import '../core/constants/route_names.dart';
import '../core/services/inspection_service.dart';
import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';

/// Video call screen for hygiene inspection. Joins Agora channel from inspection request.
class VideoCallScreen extends StatefulWidget {
  final String? channelName;
  final String? chefId;
  final String? chefName;

  const VideoCallScreen({
    super.key,
    this.channelName,
    this.chefId,
    this.chefName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isConnected = false;
  String? _error;
  RtcEngine? _engine;

  String get _channelId => widget.channelName ?? 'naham_hygiene_placeholder';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initAndJoin();
  }

  Future<void> _initAndJoin() async {
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
        channelId: _channelId,
        uid: 0,
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

  Future<void> _onEndCall() async {
    final chefId = widget.chefId;
    final chefName = widget.chefName ?? 'الطباخ';
    if (chefId != null) {
      await InspectionService().clearInspectionRequest(chefId);
    }
    if (!mounted) return;
    context.push(RouteNames.inspectionResult, extra: {'chefId': chefId ?? '', 'chefName': chefName});
    Navigator.of(context).pop();
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
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Remote video (Agora: AgoraVideoView(controller: remoteController))
            Container(
              color: Colors.black87,
              child: Center(
                child: _error != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 64, color: AppDesignSystem.errorRed),
                          const SizedBox(height: 16),
                          Text(
                            'فشل الاتصال',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : _isConnected
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_rounded, size: 80, color: NahamTheme.primary.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'مكالمة التفتيش الصحي',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                agoraAppId.isEmpty
                                    ? 'أضف AGORA_APP_ID لتشغيل المكالمة الحقيقية.'
                                    : 'سيتم عرض فيديو الطباخ هنا عند الاتصال.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: NahamTheme.primary),
                              SizedBox(height: 16),
                              Text('جاري الاتصال...', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
              ),
            ),
            // Local video (picture-in-picture)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: NahamTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
                  border: Border.all(color: NahamTheme.primary, width: 2),
                ),
                child: Center(
                  child: Icon(
                    _isVideoOff ? Icons.videocam_off_rounded : Icons.person_rounded,
                    size: 48,
                    color: NahamTheme.primary,
                  ),
                ),
              ),
            ),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: _onEndCall,
                    ),
                    const Spacer(),
                    Text(
                      'التفتيش الصحي',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            // Bottom controls
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    onPressed: () {
                      setState(() => _isMuted = !_isMuted);
                      _engine?.muteLocalAudioStream(_isMuted);
                    },
                  ),
                  const SizedBox(width: 24),
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    backgroundColor: AppDesignSystem.errorRed,
                    onPressed: _onEndCall,
                  ),
                  const SizedBox(width: 24),
                  _CallButton(
                    icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    onPressed: () {
                      setState(() => _isVideoOff = !_isVideoOff);
                      _engine?.muteLocalVideoStream(_isVideoOff);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color? backgroundColor;
  final VoidCallback onPressed;

  const _CallButton({
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? NahamTheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
