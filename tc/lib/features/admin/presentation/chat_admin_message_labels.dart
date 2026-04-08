import 'widgets/admin_design_system_widgets.dart';

/// Display name for a participant in the admin conversation thread (for labels / chips).
String adminChatSenderDisplayName({
  required String senderId,
  required String adminId,
  required String customerId,
  required String chefId,
  required String headerCustomer,
  required String headerCook,
}) {
  final s = senderId.trim();
  if (s.isEmpty) return '';
  if (adminId.isNotEmpty && s == adminId) return 'Admin';
  if (customerId.isNotEmpty && s == customerId) {
    return headerCustomer.isNotEmpty ? headerCustomer : 'Customer';
  }
  if (chefId.isNotEmpty && s == chefId) {
    return headerCook.isNotEmpty ? headerCook : 'Kitchen';
  }
  return '';
}

/// Label shown above each message bubble on [AdminSupportConversationScreen].
String adminChatMessageRoleLabel({
  required AdminMessageSenderRole role,
  required String senderDisplay,
  required bool supportLane,
}) {
  if (role == AdminMessageSenderRole.admin) {
    return supportLane ? 'Support' : 'Admin';
  }
  final s = senderDisplay.trim();
  if (s.isNotEmpty) return s;
  return role.label;
}
