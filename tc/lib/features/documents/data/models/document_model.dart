import '../../domain/entities/document_entity.dart';

class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.id,
    required super.name,
    required super.type,
    required super.fileUrl,
    required super.uploadedAt,
    super.isVerified,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DocumentType.values.firstWhere(
        (e) => e.toString() == 'DocumentType.${json['type']}',
        orElse: () => DocumentType.other,
      ),
      fileUrl: json['fileUrl'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'fileUrl': fileUrl,
      'uploadedAt': uploadedAt.toIso8601String(),
      'isVerified': isVerified,
    };
  }
}
