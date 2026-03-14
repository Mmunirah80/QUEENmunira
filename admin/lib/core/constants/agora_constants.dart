/// Agora app ID for video calls (hygiene inspection).
/// Set via environment or replace with your Agora project app ID.
const String agoraAppId = String.fromEnvironment(
  'AGORA_APP_ID',
  defaultValue: '',
);
