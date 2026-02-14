import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/screens/settings/utils/validation_utils.dart';

void main() {
  group('ValidationUtils.isValidPhoneNumber', () {
    test('accepts 10-digit number', () {
      expect(ValidationUtils.isValidPhoneNumber('2125551234'), isTrue);
    });

    test('accepts 11-digit number starting with 1', () {
      expect(ValidationUtils.isValidPhoneNumber('12125551234'), isTrue);
    });

    test('accepts formatted number with dashes and parens', () {
      expect(ValidationUtils.isValidPhoneNumber('(212) 555-1234'), isTrue);
    });

    test('rejects 9-digit number', () {
      expect(ValidationUtils.isValidPhoneNumber('212555123'), isFalse);
    });

    test('rejects 11-digit number not starting with 1', () {
      expect(ValidationUtils.isValidPhoneNumber('22125551234'), isFalse);
    });

    test('rejects empty string', () {
      expect(ValidationUtils.isValidPhoneNumber(''), isFalse);
    });

    test('rejects alphabetic input', () {
      expect(ValidationUtils.isValidPhoneNumber('abcdefghij'), isFalse);
    });
  });

  group('ValidationUtils.isValidEmail', () {
    test('accepts standard email', () {
      expect(ValidationUtils.isValidEmail('user@example.com'), isTrue);
    });

    test('accepts email with dots and plus', () {
      expect(ValidationUtils.isValidEmail('first.last+tag@domain.co'), isTrue);
    });

    test('rejects missing @', () {
      expect(ValidationUtils.isValidEmail('userexample.com'), isFalse);
    });

    test('rejects missing domain', () {
      expect(ValidationUtils.isValidEmail('user@'), isFalse);
    });

    test('rejects missing TLD', () {
      expect(ValidationUtils.isValidEmail('user@domain'), isFalse);
    });

    test('rejects empty string', () {
      expect(ValidationUtils.isValidEmail(''), isFalse);
    });

    test('rejects single-char TLD', () {
      expect(ValidationUtils.isValidEmail('user@domain.c'), isFalse);
    });
  });

  group('ValidationUtils.isValidVenmoUsername', () {
    test('accepts @username', () {
      expect(ValidationUtils.isValidVenmoUsername('@johndoe'), isTrue);
    });

    test('rejects without @', () {
      expect(ValidationUtils.isValidVenmoUsername('johndoe'), isFalse);
    });

    test('rejects bare @', () {
      expect(ValidationUtils.isValidVenmoUsername('@'), isFalse);
    });

    test('rejects empty string', () {
      expect(ValidationUtils.isValidVenmoUsername(''), isFalse);
    });
  });

  group('ValidationUtils.isValidCashtag', () {
    test('accepts \$cashtag', () {
      expect(ValidationUtils.isValidCashtag('\$johndoe'), isTrue);
    });

    test('rejects without \$', () {
      expect(ValidationUtils.isValidCashtag('johndoe'), isFalse);
    });

    test('rejects bare \$', () {
      expect(ValidationUtils.isValidCashtag('\$'), isFalse);
    });

    test('rejects empty string', () {
      expect(ValidationUtils.isValidCashtag(''), isFalse);
    });
  });
}
