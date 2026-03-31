import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/documents_repository_impl.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/documents_repository.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepositoryImpl();
});

final documentsProvider = FutureProvider<List<DocumentEntity>>((ref) async {
  final repository = ref.watch(documentsRepositoryProvider);
  return await repository.getDocuments();
});
