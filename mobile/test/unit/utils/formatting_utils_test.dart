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
