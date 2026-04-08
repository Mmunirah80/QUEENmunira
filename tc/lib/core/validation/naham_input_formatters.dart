import 'package:flutter/services.dart';

/// Shared [TextInputFormatter]s for numeric fields.
abstract final class NahamInputFormatters {
  NahamInputFormatters._();

  /// Digits 0–9 only.
  static final TextInputFormatter digitsOnly = FilteringTextInputFormatter.allow(RegExp(r'\d'));

  /// Non-negative decimal: digits and a single `.` — final shape validated with [NahamValidators.pricePositive].
  static final TextInputFormatter decimalNumber = FilteringTextInputFormatter.allow(RegExp(r'[\d.]'));

  /// Integer (optional leading digits only, no sign).
  static final TextInputFormatter unsignedInt = FilteringTextInputFormatter.allow(RegExp(r'\d'));
}
