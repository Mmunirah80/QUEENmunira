import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/validation/naham_validators.dart';

void main() {
  group('NahamValidators.pricePositive', () {
    test('accepts common valid prices', () {
      expect(NahamValidators.pricePositive('10'), isNull);
      expect(NahamValidators.pricePositive('10.5'), isNull);
      expect(NahamValidators.pricePositive('0.01'), isNull);
    });

    test('rejects invalid', () {
      expect(NahamValidators.pricePositive('abc'), isNotNull);
      expect(NahamValidators.pricePositive('-5'), isNotNull);
      expect(NahamValidators.pricePositive('0'), isNotNull);
      expect(NahamValidators.pricePositive(''), isNotNull);
    });
  });

  group('NahamValidators.personOrDishName', () {
    test('accepts normal names', () {
      expect(NahamValidators.personOrDishName('Ahmed'), isNull);
      expect(NahamValidators.personOrDishName('Kabsa plate'), isNull);
    });

    test('rejects empty and digits-only', () {
      expect(NahamValidators.personOrDishName(''), isNotNull);
      expect(NahamValidators.personOrDishName('   '), isNotNull);
      expect(NahamValidators.personOrDishName('12345'), isNotNull);
    });
  });

  group('NahamValidators.timeHHmm', () {
    test('accepts 24h', () {
      expect(NahamValidators.timeHHmm('09:00'), isNull);
      expect(NahamValidators.timeHHmm('17:30'), isNull);
      expect(NahamValidators.timeHHmm('00:00'), isNull);
      expect(NahamValidators.timeHHmm('23:59'), isNull);
    });

    test('rejects invalid', () {
      expect(NahamValidators.timeHHmm('9:00'), isNotNull);
      expect(NahamValidators.timeHHmm('25:00'), isNotNull);
      expect(NahamValidators.timeHHmm('12:60'), isNotNull);
      expect(NahamValidators.timeHHmm('9:00 AM'), isNotNull);
      expect(NahamValidators.timeHHmm(''), isNotNull);
    });
  });

  group('NahamValidators.nonNegativeDecimal', () {
    test('accepts zero and positives', () {
      expect(NahamValidators.nonNegativeDecimal('0'), isNull);
      expect(NahamValidators.nonNegativeDecimal('12.5'), isNull);
    });

    test('rejects negative and invalid', () {
      expect(NahamValidators.nonNegativeDecimal('-1'), isNotNull);
      expect(NahamValidators.nonNegativeDecimal('x'), isNotNull);
      expect(NahamValidators.nonNegativeDecimal(''), isNotNull);
    });
  });

  group('NahamValidators.phoneDigits', () {
    test('optional empty ok', () {
      expect(NahamValidators.phoneDigits('', requiredField: false), isNull);
    });

    test('required empty fails', () {
      expect(NahamValidators.phoneDigits('', requiredField: true), isNotNull);
    });
  });
}
