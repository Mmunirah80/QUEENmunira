import 'package:equatable/equatable.dart';

enum DocumentType {
  license,
  certificate,
  id,
  other,
}

class DocumentEntity extends Equatable {
  final String id;
  final String name;
  final DocumentType type;
  final String fileUrl;
  final DateTime uploadedAt;
  final bool isVerified;

  const DocumentEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.fileUrl,
    required this.uploadedAt,
    this.isVerified = false,
  });

  @override
  List<Object?> get props => [id, name, type, fileUrl, uploadedAt, isVerified];
}
