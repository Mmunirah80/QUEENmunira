import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/admin/domain/admin_cook_document_validation.dart';

void main() {
  group('isValidCookDocumentRejectionReason', () {
    test('null or empty fails', () {
      expect(isValidCookDocumentRejectionReason(null), isFalse);
      expect(isValidCookDocumentRejectionReason(''), isFalse);
      expect(isValidCookDocumentRejectionReason('   '), isFalse);
    });

    test('shorter than 5 characters fails', () {
      expect(isValidCookDocumentRejectionReason('abcd'), isFalse);
    });

    test('at least 5 non-whitespace characters passes', () {
      expect(isValidCookDocumentRejectionReason('abcde'), isTrue);
      expect(isValidCookDocumentRejectionReason('  hello  '), isTrue);
    });
  });
}
