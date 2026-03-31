import 'package:equatable/equatable.dart';

class ChatEntity extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String? userImageUrl;
  /// Optional display hint (e.g. cook opened chat from an order). Routing uses one thread per customer–chef pair.
  final String? orderId;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  const ChatEntity({
    required this.id,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    this.orderId,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        userImageUrl,
        orderId,
        lastMessage,
        lastMessageTime,
        unreadCount,
      ];
}

class MessageEntity extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  @override
  List<Object?> get props => [id, chatId, senderId, content, timestamp, isRead];
}
