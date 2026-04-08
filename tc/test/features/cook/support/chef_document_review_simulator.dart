import 'package:naham_cook_app/features/cook/data/chef_documents_compliance.dart';

/// In-memory chef_documents state (one row per [document_type]) for deterministic tests.
/// Does not hit Supabase.
class ChefDocumentReviewSimulator {
  ChefDocumentReviewSimulator(Map<String, Map<String, dynamic>> initial) {
    for (final e in initial.entries) {
      _byType[e.key] = Map<String, dynamic>.from(e.value);
    }
  }

  final Map<String, Map<String, dynamic>> _byType = {};

  List<Map<String, dynamic>> get rows => _byType.values.toList();

  ChefDocumentsCompliance compliance() => ChefDocumentsCompliance.evaluate(rows);

  Map<String, dynamic>? row(String documentType) =>
      _byType[documentType] == null ? null : Map<String, dynamic>.from(_byType[documentType]!);

  void putRow(String documentType, Map<String, dynamic> row) {
    _byType[documentType] = Map<String, dynamic>.from(row);
  }

  /// Admin approves a single document type; other types unchanged.
  void approve(String documentType) {
    final r = _require(documentType);
    _byType[documentType] = {
      ...r,
      'status': 'approved',
      'rejection_reason': null,
    };
  }

  /// Admin rejects one document; stores reason for chef UI.
  void reject(String documentType, String rejectionReason) {
    final r = _require(documentType);
    _byType[documentType] = {
      ...r,
      'status': 'rejected',
      'rejection_reason': rejectionReason,
    };
  }

  /// Chef re-upload after rejection → pending_review (RPC semantics simplified).
  void chefResubmit(String documentType) {
    final r = _require(documentType);
    _byType[documentType] = {
      ...r,
      'status': 'pending_review',
      'rejection_reason': null,
    };
  }

  /// First-time upload (registration-style).
  void submitPending(String documentType, {String? expiry, bool noExpiry = false}) {
    _byType[documentType] = {
      'document_type': documentType,
      'status': 'pending_review',
      'no_expiry': noExpiry,
      if (expiry != null) 'expiry_date': expiry,
    };
  }

  Map<String, dynamic> _require(String documentType) {
    final r = _byType[documentType];
    if (r == null) {
      throw StateError('missing document_type=$documentType');
    }
    return Map<String, dynamic>.from(r);
  }
}
