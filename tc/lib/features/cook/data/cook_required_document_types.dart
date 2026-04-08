/// Cook onboarding requires exactly **two** verification documents (no third slot).
///
/// Legacy DB rows may still use [legacyNationalIdTypes] / [legacyHealthTypes]; always
/// normalize through [canonicalDocumentType] for compliance and admin review.
abstract final class CookRequiredDocumentTypes {
  static const String idDocument = 'id_document';
  static const String healthOrKitchen = 'health_or_kitchen_document';

  static const List<String> requiredSlots = [idDocument, healthOrKitchen];

  static const Set<String> legacyNationalIdTypes = {'national_id', idDocument};
  static const Set<String> legacyHealthTypes = {
    'freelancer_id',
    'license',
    'health_or_kitchen_document',
  };

  /// Maps any known alias to [idDocument] or [healthOrKitchen]; other types pass through lowercased.
  static String canonicalDocumentType(String? raw) {
    final t = (raw ?? '').toString().trim().toLowerCase();
    if (t.isEmpty) return t;
    if (legacyNationalIdTypes.contains(t)) return idDocument;
    if (legacyHealthTypes.contains(t)) return healthOrKitchen;
    return t;
  }

  static bool isRequiredSlot(String? canonical) {
    final c = (canonical ?? '').trim().toLowerCase();
    return c == idDocument || c == healthOrKitchen;
  }

  /// Keeps the effective row per canonical slot: newest [created_at] wins; ties favor later list index.
  static Map<String, Map<String, dynamic>> latestRowPerRequiredSlot(
    List<Map<String, dynamic>> rows,
  ) {
    final indexed = <({Map<String, dynamic> r, int i})>[];
    for (var i = 0; i < rows.length; i++) {
      indexed.add((r: rows[i], i: i));
    }
    indexed.sort((a, b) {
      final ta = DateTime.tryParse((a.r['created_at'] ?? '').toString());
      final tb = DateTime.tryParse((b.r['created_at'] ?? '').toString());
      if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
      final sa = canonicalDocumentType(a.r['document_type']?.toString());
      final sb = canonicalDocumentType(b.r['document_type']?.toString());
      final aCanon = (a.r['document_type'] ?? '').toString().toLowerCase().trim() == sa;
      final bCanon = (b.r['document_type'] ?? '').toString().toLowerCase().trim() == sb;
      if (aCanon != bCanon) return aCanon ? -1 : 1;
      return b.i.compareTo(a.i);
    });

    final bySlot = <String, Map<String, dynamic>>{};
    for (final item in indexed) {
      final r = item.r;
      final slot = canonicalDocumentType(r['document_type']?.toString());
      if (!isRequiredSlot(slot)) continue;
      bySlot.putIfAbsent(slot, () => Map<String, dynamic>.from(r));
    }
    return bySlot;
  }

  static String labelForSlot(String slot) {
    switch (slot) {
      case idDocument:
        return 'ID document';
      case healthOrKitchen:
        return 'Health or kitchen document';
      default:
        return slot.replaceAll('_', ' ');
    }
  }

  /// UI label for any stored [document_type] (maps legacy aliases to the two canonical slots).
  static String displayLabelForRawDocumentType(String? raw) {
    final c = canonicalDocumentType(raw);
    if (isRequiredSlot(c)) return labelForSlot(c);
    final t = (raw ?? '').toString().trim().toLowerCase();
    if (t.isEmpty) return 'Document';
    return t.replaceAll('_', ' ');
  }
}
