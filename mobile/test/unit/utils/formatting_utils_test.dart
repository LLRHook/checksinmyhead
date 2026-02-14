import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/screens/settings/utils/formatting_utils.dart';

void main() {
  group('FormattingUtils.formatPhoneNumber', () {
    test('formats 10-digit number', () {
      expect(
        FormattingUtils.formatPhoneNumber('2125551234'),
        equals('(212) 555-1234'),
      );
    });

    test('formats 11-digit number by stripping country code', () {
      expect(
        FormattingUtils.formatPhoneNumber('12125551234'),
        equals('(212) 555-1234'),
      );
    });

    test('handles already-formatted input', () {
      expect(
        FormattingUtils.formatPhoneNumber('(212) 555-1234'),
        equals('(212) 555-1234'),
      );
    });

    test('handles dashed input', () {
      expect(
        FormattingUtils.formatPhoneNumber('212-555-1234'),
        equals('(212) 555-1234'),
      );
    });

    test('returns original for non-standard length', () {
      expect(FormattingUtils.formatPhoneNumber('12345'), equals('12345'));
    });
  });

  group('FormattingUtils.formatCurrency', () {
    test('formats whole dollar amount', () {
      expect(FormattingUtils.formatCurrency(100.0), equals('\$100.00'));
    });

    test('formats with cents', () {
      expect(FormattingUtils.formatCurrency(42.5), equals('\$42.50'));
    });

    test('formats zero', () {
      expect(FormattingUtils.formatCurrency(0.0), equals('\$0.00'));
    });

    test('rounds to two decimal places', () {
      expect(FormattingUtils.formatCurrency(9.999), equals('\$10.00'));
    });

    test('formats small amount', () {
      expect(FormattingUtils.formatCurrency(0.01), equals('\$0.01'));
    });
  });

  group('FormattingUtils.formatVenmoUsername', () {
    test('preserves existing @', () {
      expect(FormattingUtils.formatVenmoUsername('@john'), equals('@john'));
    });

    test('prepends @ if missing', () {
      expect(FormattingUtils.formatVenmoUsername('john'), equals('@john'));
    });
  });

  group('FormattingUtils.formatCashtag', () {
    test('preserves existing \$', () {
      expect(FormattingUtils.formatCashtag('\$john'), equals('\$john'));
    });

    test('prepends \$ if missing', () {
      expect(FormattingUtils.formatCashtag('john'), equals('\$john'));
    });
  });
}
