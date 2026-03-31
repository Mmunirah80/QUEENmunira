import '../entities/chat_entity.dart';

abstract class ChatRepository {
  Future<List<ChatEntity>> getChats();
  Future<List<MessageEntity>> getMessages(String chatId);
  Future<void> sendMessage(String chatId, String content);
  Future<void> markAsRead(String chatId);
  Future<String> getOrCreateConversation(String customerId);
}
