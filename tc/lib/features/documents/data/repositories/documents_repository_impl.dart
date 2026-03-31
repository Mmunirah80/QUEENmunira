import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/documents_repository.dart';
import '../datasources/documents_mock_datasource.dart';
import '../datasources/documents_remote_datasource.dart';
import '../models/document_model.dart';

class DocumentsRepositoryImpl implements DocumentsRepository {
  final DocumentsRemoteDataSource remoteDataSource;

  DocumentsRepositoryImpl({
    DocumentsRemoteDataSource? remoteDataSource,
  }) : remoteDataSource = remoteDataSource ?? DocumentsMockDataSource();

  @override
  Future<List<DocumentEntity>> getDocuments() async {
    try {
      final documents = await remoteDataSource.getDocuments();
      return documents;
    } catch (e) {
      throw Exception('Failed to get documents: ${e.toString()}');
    }
  }

  @override
  Future<void> uploadDocument(DocumentEntity document) async {
    try {
      final documentModel = DocumentModel(
        id: document.id,
        name: document.name,
        type: document.type,
        fileUrl: document.fileUrl,
        uploadedAt: document.uploadedAt,
        isVerified: document.isVerified,
      );
      await remoteDataSource.uploadDocument(documentModel);
    } catch (e) {
      throw Exception('Failed to upload document: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteDocument(String id) async {
    try {
      await remoteDataSource.deleteDocument(id);
    } catch (e) {
      throw Exception('Failed to delete document: ${e.toString()}');
    }
  }
}
