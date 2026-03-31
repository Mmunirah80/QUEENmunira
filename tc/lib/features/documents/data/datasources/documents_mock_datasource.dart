import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/document_entity.dart';
import '../models/document_model.dart';
import 'documents_remote_datasource.dart';

class DocumentsMockDataSource implements DocumentsRemoteDataSource {
  final List<DocumentModel> _documents = [];

  DocumentsMockDataSource() {
    _initializeMockData();
  }

  void _initializeMockData() {
    final now = DateTime.now();
    _documents.addAll([
      DocumentModel(
        id: 'doc_1',
        name: 'Cooking License',
        type: DocumentType.license,
        fileUrl: 'https://example.com/license.pdf',
        uploadedAt: now.subtract(const Duration(days: 30)),
        isVerified: true,
      ),
      DocumentModel(
        id: 'doc_2',
        name: 'Food Safety Certificate',
        type: DocumentType.certificate,
        fileUrl: 'https://example.com/certificate.pdf',
        uploadedAt: now.subtract(const Duration(days: 20)),
        isVerified: true,
      ),
      DocumentModel(
        id: 'doc_3',
        name: 'ID Document',
        type: DocumentType.id,
        fileUrl: 'https://example.com/id.pdf',
        uploadedAt: now.subtract(const Duration(days: 10)),
        isVerified: false,
      ),
    ]);
  }

  @override
  Future<List<DocumentModel>> getDocuments() async {
    await Future.delayed(AppConstants.mockDelay);
    return List.from(_documents);
  }

  @override
  Future<void> uploadDocument(DocumentModel document) async {
    await Future.delayed(const Duration(seconds: 2));
    _documents.add(document);
  }

  @override
  Future<void> deleteDocument(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _documents.removeWhere((doc) => doc.id == id);
  }
}
