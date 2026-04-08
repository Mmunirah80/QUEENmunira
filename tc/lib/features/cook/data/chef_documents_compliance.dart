import 'cook_required_document_types.dart';

/// Interprets [chef_documents] rows for a single chef (one effective row per required slot).
///
/// Rules:
/// - Required slots [CookRequiredDocumentTypes.requiredSlots] must be `approved` with valid expiry.
/// - `pending_review`, `rejected`, `expired` fail operations until resolved.
/// - Legacy [national_id]/[freelancer_id]/[license] rows are merged into the two canonical slots.
class ChefDocumentsCompliance {
  ChefDocumentsCompliance({
    required this.canReceiveOrders,
    required this.expiringWithinDays,
  });

  /// Canonical types only (for callers/tests).
  static List<String> get requiredTypes => List<String>.from(CookRequiredDocumentTypes.requiredSlots);

  final bool canReceiveOrders;

  final Map<String, int> expiringWithinDays;

  static ChefDocumentsCompliance evaluate(
    List<Map<String, dynamic>> rows, {
    int warnWithinDays = 7,
  }) {
    final bySlot = CookRequiredDocumentTypes.latestRowPerRequiredSlot(rows);

    var ok = true;
    for (final slot in CookRequiredDocumentTypes.requiredSlots) {
      final row = bySlot[slot];
      if (!_typeAllowsOperations(row)) {
        ok = false;
      }
    }

    final expiring = <String, int>{};
    if (warnWithinDays > 0) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final slot in CookRequiredDocumentTypes.requiredSlots) {
        final row = bySlot[slot];
        if (row == null) continue;
        if ((row['status'] ?? '').toString().toLowerCase() != 'approved') {
          continue;
        }
        if (row['no_expiry'] == true) continue;
        final exp = _parseDateOnly(row['expiry_date']);
        if (exp == null) continue;
        final d = exp.difference(today).inDays;
        if (d >= 0 && d <= warnWithinDays) {
          expiring[slot] = d;
        }
      }
    }

    return ChefDocumentsCompliance(
      canReceiveOrders: ok,
      expiringWithinDays: expiring,
    );
  }

  static DateTime? _parseDateOnly(Object? v) {
    if (v == null) return null;
    if (v is DateTime) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is String) {
      final p = DateTime.tryParse(v);
      if (p == null) return null;
      return DateTime(p.year, p.month, p.day);
    }
    return null;
  }

  static bool isDocumentExpired(Object? expiryRaw) => _isExpired(expiryRaw);

  static bool _isExpired(Object? expiryRaw) {
    final exp = _parseDateOnly(expiryRaw);
    if (exp == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return exp.isBefore(today);
  }

  /// Single effective row per required slot.
  static bool _typeAllowsOperations(Map<String, dynamic>? row) {
    if (row == null) return false;
    final st = (row['status'] ?? '').toString().toLowerCase();
    if (st == 'rejected' || st == 'pending_review' || st == 'expired') {
      return false;
    }
    if (st != 'approved') return false;
    if (row['no_expiry'] == true) return true;
    if (isDocumentExpired(row['expiry_date'])) return false;
    return true;
  }
}
