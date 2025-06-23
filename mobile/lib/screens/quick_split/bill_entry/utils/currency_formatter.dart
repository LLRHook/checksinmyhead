// Spliq: Privacy-first receipt spliting
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

import 'package:flutter/services.dart';

/// CurrencyFormatter - Utility class for consistent currency formatting
///
/// Provides tools for formatting and validating currency values throughout
/// the application. Ensures consistent representation of monetary amounts.
///
/// Features:
///   - Input validation for currency text fields (numbers with up to 2 decimal places)
///   - Formatting doubles as currency strings with dollar sign and 2 decimal places
class CurrencyFormatter {
  /// TextInputFormatter that restricts input to valid currency format
  ///
  /// Allows only:
  ///   - Digits (0-9)
  ///   - A single decimal point
  ///   - Maximum of 2 decimal places
  static final TextInputFormatter currencyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'));

  /// Converts a numeric value to a formatted currency string
  ///
  /// Formats the given value with a dollar sign prefix and exactly
  /// two decimal places (e.g., $12.34, $0.50, $100.00)
  static String formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}
