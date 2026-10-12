// Billington: Privacy-first receipt spliting
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
import 'package:checks_frontend/screens/settings/models/payment_method.dart';

class FormattingUtils {
  static String formatPhoneNumber(String phoneNumber) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    String digits;
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      digits = digitsOnly.substring(1);
    } else {
      digits = digitsOnly;
    }

    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }

    return phoneNumber;
  }

  static String formatVenmoUsername(String username) {
    if (username.startsWith('@')) {
      return username;
    }
    return '@$username';
  }

  static String formatCashtag(String cashtag) {
    if (cashtag.startsWith('\$')) {
      return cashtag;
    }
    return '\$$cashtag';
  }

  static String formatPaymentIdentifier(String method, String value) {
    if (PaymentMethod.requiresPhoneNumber(method)) {
      return formatPhoneNumber(value);
    }
    if (method == 'Venmo') return formatVenmoUsername(value);
    if (method == 'Cash App') return formatCashtag(value);
    return value;
  }
}
