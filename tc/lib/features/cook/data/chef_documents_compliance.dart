/// Interprets [chef_documents] rows for a single chef (any sort order).
///
/// Rules (onboarding vs renewal):
/// - If the **newest** row for a type is `rejected`, that type fails (admin
///   rejected the latest submission — stop operations until fixed).
/// - Otherwise the type passes if **any** row (newest first) is `approved` and
///   not past [expiry_date]. So a new `pending` upload does not block work while
///   an older approved doc is still valid.
class ChefDocumentsCompliance {
  ChefDocumentsCompliance({
    required this.canReceiveOrders,
    required this.expiringWithinDays,
  });

  /// Types that must pass [_typeAllowsOperations] for the cook to go online.
  static const List<String> requiredTypes = [
    'national_id',
    'freelancer_id',
  ];

  final bool canReceiveOrders;

  /// document_type → days until expiry for the **latest approved** row with an
  /// expiry date (null expiry ignored). Only non-negative days &le; [within].
  final Map<String, int> expiringWithinDays;

  static ChefDocumentsCompliance evaluate(
    List<Map<String, dynamic>> rows, {
    int warnWithinDays = 7,
  }) {
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final t = (r['document_type'] ?? '').toString();
      byType.putIfAbsent(t, () => []).add(Map<String, dynamic>.from(r));
    }
    for (final list in byType.values) {
      list.sort((a, b) {
        final ca = _parseCreated(a['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final cb = _parseCreated(b['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return cb.compareTo(ca);
      });
    }

    var ok = true;
    for (final t in requiredTypes) {
      final list = byType[t] ?? [];
      if (!_typeAllowsOperations(list)) {
        ok = false;
      }
    }

    final expiring = <String, int>{};
    if (warnWithinDays > 0) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final t in requiredTypes) {
        final list = byType[t] ?? [];
        for (final r in list) {
          if ((r['status'] ?? '').toString().toLowerCase() != 'approved') {
            continue;
          }
          final exp = _parseDateOnly(r['expiry_date']);
          if (exp == null) continue;
          final d = exp.difference(today).inDays;
          if (d >= 0 && d <= warnWithinDays) {
            expiring[t] = d;
            break;
          }
        }
      }
    }

    return ChefDocumentsCompliance(
      canReceiveOrders: ok,
      expiringWithinDays: expiring,
    );
  }

  static DateTime? _parseCreated(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
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

  /// `expiry_date` is inclusive for that calendar day; expired starting next day.
  static bool isDocumentExpired(Object? expiryRaw) => _isExpired(expiryRaw);

  static bool _isExpired(Object? expiryRaw) {
    final exp = _parseDateOnly(expiryRaw);
    if (exp == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return exp.isBefore(today);
  }

  /// Newest-first list for one [document_type].
  static bool _typeAllowsOperations(List<Map<String, dynamic>> sortedNewestFirst) {
    if (sortedNewestFirst.isEmpty) return false;
    final latestStatus =
        (sortedNewestFirst.first['status'] ?? '').toString().toLowerCase();
    if (latestStatus == 'rejected') return false;
    for (final r in sortedNewestFirst) {
      final st = (r['status'] ?? '').toString().toLowerCase();
      if (st != 'approved') continue;
      if (isDocumentExpired(r['expiry_date'])) continue;
      return true;
    }
    return false;
  }
}
