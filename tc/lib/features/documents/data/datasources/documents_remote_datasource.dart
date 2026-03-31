import '../../domain/entities/document_entity.dart';
import '../models/document_model.dart';

abstract class DocumentsRemoteDataSource {
  Future<List<DocumentModel>> getDocuments();
  Future<void> uploadDocument(DocumentModel document);
  Future<void> deleteDocument(String id);
}
