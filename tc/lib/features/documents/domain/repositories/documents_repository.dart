import '../entities/document_entity.dart';

abstract class DocumentsRepository {
  Future<List<DocumentEntity>> getDocuments();
  Future<void> uploadDocument(DocumentEntity document);
  Future<void> deleteDocument(String id);
}
