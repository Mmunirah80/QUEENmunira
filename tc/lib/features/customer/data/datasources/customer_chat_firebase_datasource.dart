import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore chats for customer: customer-chef and customer-support.
/// chats/{chatId}: type, participantIds, otherParticipantName, lastMessage, lastMessageAt
/// chats/{chatId}/messages/{messageId}: senderId, content, createdAt
class CustomerChatFirebaseDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _chats = 'chats';

  /// Stream of chats where [customerId] is participant and type is [type].
  Stream<List<Map<String, dynamic>>> watchChatsByType(
    String customerId,
    String type,
  ) {
    return _firestore
        .collection(_chats)
        .where('participantIds', arrayContains: customerId)
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['id'] = d.id;
            final at = data['lastMessageAt'];
            data['lastMessageAt'] = at is Timestamp
                ? at.toDate()
                : null;
            return data;
          }).toList();
          list.sort((a, b) {
            final atA = a['lastMessageAt'] as DateTime?;
            final atB = b['lastMessageAt'] as DateTime?;
            if (atA == null && atB == null) return 0;
            if (atA == null) return 1;
            if (atB == null) return -1;
            return atB.compareTo(atA);
          });
          return list;
        });
  }

  /// Stream messages for a chat.
  Stream<List<Map<String, dynamic>>> watchMessages(String chatId) {
    return _firestore
        .collection(_chats)
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              final at = data['createdAt'];
              data['createdAt'] = at is Timestamp
                  ? at.toDate().toIso8601String()
                  : at?.toString();
              return data;
            }).toList());
  }

  /// Send a text message. Creates message doc and updates chat lastMessage/lastMessageAt.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String content,
  }) async {
    final batch = _firestore.batch();
    final msgRef = _firestore
        .collection(_chats)
        .doc(chatId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final chatRef = _firestore.collection(_chats).doc(chatId);
    batch.update(chatRef, {
      'lastMessage': content,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Get or create a customer-chef chat. Returns chat id.
  Future<String> getOrCreateCustomerChefChat({
    required String customerId,
    required String customerName,
    required String chefId,
    required String chefName,
  }) async {
    final snap = await _firestore
        .collection(_chats)
        .where('participantIds', arrayContains: customerId)
        .where('type', isEqualTo: 'customer-chef')
        .get();
    for (final d in snap.docs) {
      final raw = d.data()['participantIds'];
      final ids = List<String>.from((raw is List?) ? raw ?? [] : []);
      if (ids.contains(chefId)) return d.id;
    }
    final ref = _firestore.collection(_chats).doc();
    await ref.set({
      'type': 'customer-chef',
      'participantIds': [customerId, chefId],
      'otherParticipantName': chefName,
      'otherParticipantId': chefId,
      'lastMessage': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Get or create customer-support chat.
  Future<String> getOrCreateCustomerSupportChat({
    required String customerId,
    required String customerName,
  }) async {
    const supportName = 'Naham Support';
    const supportId = 'support';
    final snap = await _firestore
        .collection(_chats)
        .where('participantIds', arrayContains: customerId)
        .where('type', isEqualTo: 'customer-support')
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    final ref = _firestore.collection(_chats).doc();
    await ref.set({
      'type': 'customer-support',
      'participantIds': [customerId, supportId],
      'otherParticipantName': supportName,
      'otherParticipantId': supportId,
      'lastMessage': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}
