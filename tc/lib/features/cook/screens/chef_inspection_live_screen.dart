import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/agora_constants.dart';
import '../../inspection_live/inspection_rtc_helper.dart';

/// After the cook **accepts** an inspection, this screen turns on the camera and publishes to the channel.
/// Admin joins separately as a viewer only (no camera).
class ChefInspectionLiveScreen extends StatefulWidget {
  const ChefInspectionLiveScreen({
    super.key,
    required this.callId,
    required this.channelName,
  });

  final String callId;
  final String channelName;

  @override
  State<ChefInspectionLiveScreen> createState() => _ChefInspectionLiveScreenState();
}

class _ChefInspectionLiveScreenState extends State<ChefInspectionLiveScreen> {
  RtcEngine? _engine;
  RtcEngineEventHandler? _handler;
  bool _joined = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    unawaited(_start());
  }

  Future<void> _start() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        setState(() {
          _error = 'Camera and microphone permission are required for the inspection.';
        });
      }
      return;
    }

    if (agoraAppId.isEmpty) {
      if (mounted) setState(() => _joined = true);
      return;
    }

    try {
      final engine = await InspectionRtcHelper.createEngine();
      await InspectionRtcHelper.prepareChefPublisher(engine);
      _handler = RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          if (mounted) setState(() => _joined = true);
        },
        onError: (err, msg) {
          if (mounted) setState(() => _error = msg);
        },
      );
      await InspectionRtcHelper.joinChefChannel(
        engine: engine,
        channelName: widget.channelName,
        handler: _handler!,
      );
      _engine = engine;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
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

  Future<void> _hangUp() async {
    await InspectionRtcHelper.safeDispose(_engine);
    _engine = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live inspection'),
        actions: [
          TextButton(
            onPressed: _hangUp,
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: agoraAppId.isNotEmpty && _engine != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine!,
                                canvas: const VideoCanvas(uid: 0),
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
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Your camera is on. The reviewer sees this picture-in-picture only — they cannot turn your camera on.',
                                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'AGORA_APP_ID is not set in this build. The inspection session is still active in the database; '
                              'connect a valid Agora project to stream video.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, height: 1.4),
                            ),
                          ),
                        ),
                ),
                if (_joined || agoraAppId.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          agoraAppId.isEmpty ? Icons.info_outline : Icons.videocam_rounded,
                          color: Colors.greenAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          agoraAppId.isEmpty ? 'Development mode (no video SDK)' : 'Connected — reviewer is viewing',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade700,
        onPressed: _hangUp,
        child: const Icon(Icons.call_end_rounded),
      ),
    );
  }
}
