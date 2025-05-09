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
/// Utility methods for formatting text values
class FormattingUtils {
  /// Formats a phone number in a standard way (XXX) XXX-XXXX
  static String formatPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Handle US numbers with or without country code
    String digits;
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      digits = digitsOnly.substring(1); // Remove country code
    } else {
      digits = digitsOnly;
    }

    // Only format if we have exactly 10 digits
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }

    // Otherwise return original input
    return phoneNumber;
  }

  /// Formats a currency amount as USD
  static String formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Ensures a Venmo username starts with @
  static String formatVenmoUsername(String username) {
    if (username.startsWith('@')) {
      return username;
    }
    return '@$username';
  }

  /// Ensures a Cash App cashtag starts with $
  static String formatCashtag(String cashtag) {
    if (cashtag.startsWith('\$')) {
      return cashtag;
    }
    return '\$$cashtag';
  }
}
