import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/screens/settings/utils/validation_utils.dart';

void _validationCases(
  String method,
  bool Function(String) validate,
  Map<String, (String, bool)> cases,
) {
  group('ValidationUtils.$method', () {
    for (final entry in cases.entries) {
      final (input, expected) = entry.value;
      test(entry.key, () {
        expect(validate(input), expected);
      });
    }
  });
}

void main() {
  _validationCases('isValidPhoneNumber', ValidationUtils.isValidPhoneNumber, {
    'accepts 10-digit number': ('2125551234', true),
    'accepts 11-digit number starting with 1': ('12125551234', true),
    'accepts formatted number with dashes and parens': ('(212) 555-1234', true),
    'rejects 9-digit number': ('212555123', false),
    'rejects 11-digit number not starting with 1': ('22125551234', false),
    'rejects empty string': ('', false),
    'rejects alphabetic input': ('abcdefghij', false),
  });

  _validationCases('isValidEmail', ValidationUtils.isValidEmail, {
    'accepts standard email': ('user@example.com', true),
    'accepts email with dots and plus': ('first.last+tag@domain.co', true),
    'rejects missing @': ('userexample.com', false),
    'rejects missing domain': ('user@', false),
    'rejects missing TLD': ('user@domain', false),
    'rejects empty string': ('', false),
    'rejects single-char TLD': ('user@domain.c', false),
  });

  _validationCases(
    'isValidVenmoUsername',
    ValidationUtils.isValidVenmoUsername,
    {
      'accepts @username': ('@johndoe', true),
      'rejects without @': ('johndoe', false),
      'rejects bare @': ('@', false),
      'rejects empty string': ('', false),
    },
  );

  _validationCases('isValidCashtag', ValidationUtils.isValidCashtag, {
    'accepts \$cashtag': ('\$johndoe', true),
    'rejects without \$': ('johndoe', false),
    'rejects bare \$': ('\$', false),
    'rejects empty string': ('', false),
  });
}
