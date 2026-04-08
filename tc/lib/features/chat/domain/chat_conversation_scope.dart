/// Predicates for which [conversations] rows belong on a chef inbox stream.
abstract final class ChatConversationScope {
  ChatConversationScope._();

  /// Customer ↔ chef marketplace threads for the signed-in cook.
  static bool chefCustomerChefInboxRow({
    required Map<String, dynamic> row,
    required String sessionChefId,
  }) {
    final rowChefId = (row['chef_id'] ?? '').toString();
    final rowType = (row['type'] ?? '').toString();
    return rowChefId == sessionChefId && rowType == 'customer-chef';
  }

  /// Admin ↔ chef support threads.
  static bool chefAdminSupportInboxRow({
    required Map<String, dynamic> row,
    required String sessionChefId,
  }) {
    final rowChefId = (row['chef_id'] ?? '').toString();
    final rowType = (row['type'] ?? '').toString();
    return rowChefId == sessionChefId && rowType == 'chef-admin';
  }

  /// Customer ↔ chef marketplace threads for the signed-in customer.
  /// Matches [CustomerChatSupabaseDatasource] filters (`.eq('customer_id', …)`, `type` = `customer-chef`).
  static bool customerChefInboxRow({
    required Map<String, dynamic> row,
    required String sessionCustomerId,
  }) {
    final cid = (row['customer_id'] ?? '').toString();
    final rowType = (row['type'] ?? '').toString();
    return cid == sessionCustomerId && rowType == 'customer-chef';
  }

  /// Customer ↔ support threads (`customer-support`).
  static bool customerSupportInboxRow({
    required Map<String, dynamic> row,
    required String sessionCustomerId,
  }) {
    final cid = (row['customer_id'] ?? '').toString();
    final rowType = (row['type'] ?? '').toString();
    return cid == sessionCustomerId && rowType == 'customer-support';
  }
}
