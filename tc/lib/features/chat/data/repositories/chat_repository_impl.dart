import '../../domain/entities/chat_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_mock_datasource.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl({
    ChatRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? ChatMockDataSource();

  @override
  Future<List<ChatEntity>> getChats() => remoteDataSource.getChats();

  @override
  Future<List<MessageEntity>> getMessages(String chatId) =>
      remoteDataSource.getMessages(chatId);

  @override
  Future<void> sendMessage(String chatId, String content) =>
      remoteDataSource.sendMessage(chatId, content);

  @override
  Future<void> markAsRead(String chatId) => remoteDataSource.markAsRead(chatId);

  @override
  Future<String> getOrCreateConversation(String customerId) =>
      remoteDataSource.getOrCreateConversation(customerId);
}
