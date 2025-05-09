// Checkmate: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

/// Utility methods for validating user input
class ValidationUtils {
  /// Validates a phone number for Zelle and Apple Pay
  /// Returns true if the number is valid, false otherwise
  static bool isValidPhoneNumber(String value) {
    // Remove any non-digit characters (spaces, dashes, parentheses)
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // US phone numbers should be 10 digits (ignoring country code)
    // Or 11 digits if they include the US country code (1)
    if (digitsOnly.length == 10) {
      return true;
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      return true;
    }

    return false;
  }

  /// Validates an email address
  /// Returns true if the email is valid, false otherwise
  static bool isValidEmail(String value) {
    // Simple email validation regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(value);
  }

  /// Validates a Venmo username
  /// Returns true if the username is valid, false otherwise
  static bool isValidVenmoUsername(String value) {
    // Venmo usernames start with @ and have at least one character after it
    if (!value.startsWith('@')) {
      return false;
    }

    // Remove the @ and check if there's at least one character
    final username = value.substring(1);
    return username.isNotEmpty;
  }

  /// Validates a Cash App cashtag
  /// Returns true if the cashtag is valid, false otherwise
  static bool isValidCashtag(String value) {
    // Cash App cashtags start with $ and have at least one character after it
    if (!value.startsWith('\$')) {
      return false;
    }

    // Remove the $ and check if there's at least one character
    final cashtag = value.substring(1);
    return cashtag.isNotEmpty;
  }
}
