import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/screens/settings/utils/validation_utils.dart';

void main() {
  group('ValidationUtils tests', () {
    group('isValidPhoneNumber tests', () {
      test('validates standard 10-digit phone number', () {
        expect(ValidationUtils.isValidPhoneNumber('1234567890'), true);
        expect(ValidationUtils.isValidPhoneNumber('9876543210'), true);
      });

      test('validates formatted 10-digit phone number', () {
        expect(ValidationUtils.isValidPhoneNumber('(123) 456-7890'), true);
        expect(ValidationUtils.isValidPhoneNumber('123-456-7890'), true);
        expect(ValidationUtils.isValidPhoneNumber('123.456.7890'), true);
      });

      test('validates 11-digit phone number with country code', () {
        expect(ValidationUtils.isValidPhoneNumber('11234567890'), true);
        expect(ValidationUtils.isValidPhoneNumber('+11234567890'), true);
        expect(ValidationUtils.isValidPhoneNumber('1-123-456-7890'), true);
      });

      test('rejects invalid phone numbers', () {
        expect(
          ValidationUtils.isValidPhoneNumber('123456'),
          false,
        ); // too short
        expect(
          ValidationUtils.isValidPhoneNumber('12345678901234'),
          false,
        ); // too long
        expect(
          ValidationUtils.isValidPhoneNumber('21234567890'),
          false,
        ); // 11 digits but wrong country code
        expect(
          ValidationUtils.isValidPhoneNumber('abcdefghij'),
          false,
        ); // not numeric
      });
    });

    group('isValidEmail tests', () {
      test('validates standard email addresses', () {
        expect(ValidationUtils.isValidEmail('test@example.com'), true);
        expect(ValidationUtils.isValidEmail('user.name@example.co.uk'), true);
        expect(ValidationUtils.isValidEmail('user+tag@example.org'), true);
        expect(ValidationUtils.isValidEmail('user-name@example.io'), true);
      });

      test('rejects invalid email addresses', () {
        expect(ValidationUtils.isValidEmail('test'), false); // no @ symbol
        expect(ValidationUtils.isValidEmail('test@'), false); // no domain
        expect(
          ValidationUtils.isValidEmail('@example.com'),
          false,
        ); // no username
        expect(
          ValidationUtils.isValidEmail('test@example'),
          false,
        ); // incomplete domain
        expect(
          ValidationUtils.isValidEmail('test@.com'),
          false,
        ); // missing domain name
        expect(
          ValidationUtils.isValidEmail('test@example.'),
          false,
        ); // incomplete TLD
      });
    });

    group('isValidVenmoUsername tests', () {
      test('validates valid Venmo usernames', () {
        expect(ValidationUtils.isValidVenmoUsername('@user'), true);
        expect(ValidationUtils.isValidVenmoUsername('@user123'), true);
        expect(ValidationUtils.isValidVenmoUsername('@user-name'), true);
        expect(
          ValidationUtils.isValidVenmoUsername('@username_with_underscore'),
          true,
        );
      });

      test('rejects invalid Venmo usernames', () {
        expect(
          ValidationUtils.isValidVenmoUsername('user'),
          false,
        ); // missing @ prefix
        expect(
          ValidationUtils.isValidVenmoUsername('@'),
          false,
        ); // no username after @
        expect(ValidationUtils.isValidVenmoUsername(''), false); // empty string
      });
    });

    group('isValidCashtag tests', () {
      test('validates valid Cashtags', () {
        expect(ValidationUtils.isValidCashtag('\$user'), true);
        expect(ValidationUtils.isValidCashtag('\$user123'), true);
        expect(ValidationUtils.isValidCashtag('\$user_name'), true);
      });

      test('rejects invalid Cashtags', () {
        expect(
          ValidationUtils.isValidCashtag('user'),
          false,
        ); // missing $ prefix
        expect(
          ValidationUtils.isValidCashtag('\$'),
          false,
        ); // no username after $
        expect(ValidationUtils.isValidCashtag(''), false); // empty string
      });
    });
  });
}
