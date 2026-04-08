/// Reusable input validation (returns `null` when valid, else error message).
library;

final RegExp _emailLoose = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _hhmm = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

abstract final class NahamValidators {
  NahamValidators._();

  static String? requiredText(String? value, {int minLength = 1, String emptyMessage = 'Required'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return emptyMessage;
    if (t.length < minLength) {
      return minLength == 1 ? emptyMessage : 'At least $minLength characters';
    }
    return null;
  }

  /// Fails if the visible text is only ASCII digits (e.g. "12345" as a name).
  static String? notOnlyDigits(String? value, {String message = 'Cannot be only numbers'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(t)) return message;
    return null;
  }

  /// Dish / person name: required, min length, not only digits.
  static String? personOrDishName(String? value, {int minLength = 2}) {
    final req = requiredText(value, minLength: minLength);
    if (req != null) return req;
    return notOnlyDigits(value);
  }

  /// Positive decimal price (> 0). Allows "10", "10.5", "0.99".
  static String? pricePositive(String? value, {String message = 'Enter a valid price'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return message;
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null || n <= 0) return message;
    if (!n.isFinite) return message;
    return null;
  }

  /// Non-negative decimal (≥ 0), e.g. ingredient line cost.
  static String? nonNegativeDecimal(String? value, {String message = 'Enter a valid amount'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return message;
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null || n < 0 || !n.isFinite) return message;
    return null;
  }

  /// Integer >= 0.
  static String? nonNegativeInt(String? value, {String message = 'Enter a whole number ≥ 0'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return message;
    final n = int.tryParse(t);
    if (n == null || n < 0) return message;
    return null;
  }

  /// Positive integer (> 0) e.g. servings.
  static String? positiveInt(String? value, {String message = 'Enter a number greater than 0'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return message;
    final n = int.tryParse(t);
    if (n == null || n < 1) return message;
    return null;
  }

  /// Digits only (after normalizing); length in [minDigits, maxDigits]. Empty = invalid if [requiredField].
  static String? phoneDigits(
    String? value, {
    int minDigits = 8,
    int maxDigits = 15,
    bool requiredField = false,
    String emptyMessage = 'Required',
    String invalidMessage = 'Enter a valid phone number',
  }) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return requiredField ? emptyMessage : null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < minDigits || digits.length > maxDigits) return invalidMessage;
    return null;
  }

  static String? email(String? value, {String emptyMessage = 'Required', String invalidMessage = 'Invalid email'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return emptyMessage;
    if (!_emailLoose.hasMatch(t)) return invalidMessage;
    return null;
  }

  /// Reject / warning / note text.
  static String? reasonField(String? value, {int minLength = 2, String message = 'Add a reason'}) {
    final t = value?.trim() ?? '';
    if (t.length < minLength) return message;
    return null;
  }

  /// Admin rejecting a chef document — must be substantive (aligned with `apply_chef_document_review` in SQL).
  static String? adminDocumentRejectionReason(
    String? value, {
    int minLength = 5,
    String message = 'Enter a clear rejection reason (at least 5 characters)',
  }) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Rejection reason is required';
    if (t.length < minLength) return message;
    return null;
  }

  /// Strict 24h `HH:mm` (00:00–23:59).
  static String? timeHHmm(String? value, {String message = 'Use 24-hour time (HH:mm)'}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return message;
    if (!_hhmm.hasMatch(t)) return message;
    return null;
  }

  /// Free-text address / meetup description (optional or required).
  static String? addressLine(
    String? value, {
    bool requiredField = true,
    int minLength = 5,
    String emptyMessage = 'Enter an address',
    String shortMessage = 'Address is too short',
  }) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return requiredField ? emptyMessage : null;
    if (t.length < minLength) return shortMessage;
    return null;
  }

  /// Optional multi-line description (validate only if non-empty).
  static String? optionalDescription(String? value, {int maxLength = 2000}) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length > maxLength) return 'Too long (max $maxLength characters)';
    return null;
  }
}
