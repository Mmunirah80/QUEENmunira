import 'package:flutter_test/flutter_test.dart';

/// Mirrors [AdminSupabaseDatasource.fetchExpiredDocumentsForAdmin] filtering:
/// `status == approved` AND `expiry_date` (YYYY-MM-DD) strictly before [todayIso].
bool matchesExpiredApprovedDocumentsAdminQuery({
  required String status,
  required Object? expiryDate,
  required String todayIsoDate,
}) {
  if (status.toLowerCase() != 'approved') return false;
  final exp = expiryDate?.toString().trim() ?? '';
  if (exp.isEmpty) return false;
  return exp.compareTo(todayIsoDate) < 0;
}

void main() {
  group('Admin expired documents query logic', () {
    const today = '2026-04-06';

    test('approved + expiry before today => included', () {
      expect(
        matchesExpiredApprovedDocumentsAdminQuery(
          status: 'approved',
          expiryDate: '2026-04-01',
          todayIsoDate: today,
        ),
        isTrue,
      );
    });

    test('approved + expiry on or after today => excluded', () {
      expect(
        matchesExpiredApprovedDocumentsAdminQuery(
          status: 'approved',
          expiryDate: '2026-04-06',
          todayIsoDate: today,
        ),
        isFalse,
      );
      expect(
        matchesExpiredApprovedDocumentsAdminQuery(
          status: 'approved',
          expiryDate: '2026-04-07',
          todayIsoDate: today,
        ),
        isFalse,
      );
    });

    test('non-approved => never included', () {
      expect(
        matchesExpiredApprovedDocumentsAdminQuery(
          status: 'pending_review',
          expiryDate: '2020-01-01',
          todayIsoDate: today,
        ),
        isFalse,
      );
    });
  });
}
