import '../models/chat_model.dart';
import '../models/message_model.dart';

abstract class ChatRemoteDataSource {
  Future<List<ChatModel>> getChats();
  Future<List<MessageModel>> getMessages(String chatId);
  Future<void> sendMessage(String chatId, String content);
  Future<void> markAsRead(String chatId);

  /// One customer–chef thread per pair (`customer_id` + current chef).
  Future<String> getOrCreateConversation(String customerId);
}
