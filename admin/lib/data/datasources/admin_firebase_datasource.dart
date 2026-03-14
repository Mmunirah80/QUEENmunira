import '../models/user_model.dart';

/// Firestore paths match TC app: users, chefs, orders. Reject writes to both users and chefs.
class AdminFirebaseDataSource {
  static const String _users = 'users';
  static const String _chefs = 'chefs';
  static const String _adminNotifications = 'admin_notifications';
  static const String _conversations = 'conversations';

  Stream<List<UserModel>> watchPendingChefs() {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Stream<int> watchPendingChefsCount() {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Future<List<UserModel>> getAllChefs() async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Future<UserModel?> getChefById(String chefId) async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Future<void> approveChef(String chefId) {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  /// Reject: update users + chefs/{chefId}.rejectionReason (for TC ChefRejectionScreen). Cloud Function can send email.
  Future<void> rejectChef(String chefId, {required String reason}) async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Future<List<UserModel>> getAllCustomers() async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  /// Chef profile from chefs/{chefId}: documents (nationalId, healthCert), strikeCount, frozenUntil, chefStatus, violationHistory.
  Future<Map<String, dynamic>?> getChefDoc(String chefId) async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  /// Violation: append to violationHistory, update strikeCount, frozenUntil, chefStatus per punishment.
  Future<void> applyViolation({
    required String chefId,
    required String reason,
    required int newStrikeCount,
    required String punishment,
    DateTime? frozenUntil,
    required String chefStatus,
  }) async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  // ─── Admin notifications (admin_notifications collection) ─────────────
  Stream<List<Map<String, dynamic>>> watchAdminNotifications() {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Future<void> markNotificationRead(String id) {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Future<void> markAllNotificationsRead() async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  // ─── Support conversations (type customer-support or chef-support) ─────
  Stream<List<Map<String, dynamic>>> watchSupportConversations() {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Stream<int> watchSupportUnreadCount() {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Stream<List<Map<String, dynamic>>> watchConversationMessages(String conversationId) {
    throw UnimplementedError('Firebase has been removed from this project.');
  }

  Future<void> sendSupportMessage(String conversationId, String text) async {
    throw UnimplementedError('Firebase has been removed from this project.');
  }
}
