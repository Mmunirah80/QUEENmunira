import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../core/constants/agora_constants.dart';
import 'inspection_rtc_constants.dart';

/// Agora setup for random kitchen inspections.
///
/// **Chef**: broadcaster, local camera + mic (after explicit accept in UI).
/// **Admin**: same profile, broadcaster role, **local video disabled** — viewer only; sees [InspectionRtcConstants.chefUid].
///
/// When [agoraAppId] is empty, callers should skip engine creation and show non-video status UI (no fake camera).
class InspectionRtcHelper {
  InspectionRtcHelper._();

  static Future<RtcEngine> createEngine() async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(
      const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    return engine;
  }

  /// Chef side: publishes camera (call after camera/mic permission granted).
  static Future<void> prepareChefPublisher(RtcEngine engine) async {
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.enableVideo();
    await engine.enableLocalVideo(true);
    await engine.startPreview();
  }

  /// Admin side: **never** turns on local camera; subscribes to remote video only.
  static Future<void> prepareAdminViewer(RtcEngine engine) async {
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.enableVideo();
    await engine.enableLocalVideo(false);
    await engine.muteLocalVideoStream(true);
    await engine.muteLocalAudioStream(true);
  }

  static Future<void> joinChefChannel({
    required RtcEngine engine,
    required String channelName,
    required RtcEngineEventHandler handler,
  }) async {
    engine.registerEventHandler(handler);
    await engine.joinChannel(
      token: '',
      channelId: channelName,
      uid: InspectionRtcConstants.chefUid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  static Future<void> joinAdminChannel({
    required RtcEngine engine,
    required String channelName,
    required RtcEngineEventHandler handler,
  }) async {
    engine.registerEventHandler(handler);
    await engine.joinChannel(
      token: '',
      channelId: channelName,
      uid: InspectionRtcConstants.adminUid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  static Future<void> safeDispose(RtcEngine? engine) async {
    if (engine == null) return;
    try {
      await engine.leaveChannel();
    } catch (_) {}
    try {
      await engine.release();
    } catch (_) {}
  }
}
