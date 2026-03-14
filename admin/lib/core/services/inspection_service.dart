/// Result of starting an inspection request.
class InspectionRequestResult {
  final String channelName;
  final String chefId;
  final String? chefName;

  const InspectionRequestResult({
    required this.channelName,
    required this.chefId,
    this.chefName,
  });
}

/// Firestore paths (match TC):
/// - chefs/{chefId} — isOnline, strikeCount, frozenUntil
/// - chefs/{chefId}/inspection_requests/current — channelName, status: pending | accepted | rejected
class InspectionService {
  static const String _chefsCollection = 'chefs';
  static const String _inspectionRequestsSub = 'inspection_requests';
  static const String _currentDoc = 'current';

  /// Picks a random chef where isOnline == true and not frozen, writes inspection_requests/current,
  /// and returns channel name + chef id so Admin can join Agora immediately.
  Future<InspectionRequestResult?> startRandomInspection() async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  /// Called when Admin ends the call (e.g. hang up). Clears current request so Chef UI resets.
  Future<void> clearInspectionRequest(String chefId) async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }
}
