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

import 'package:flutter/services.dart';

class CurrencyFormatter {
  static final TextInputFormatter currencyFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'));

  /// Presentation only: accounting already allocates shares in integer cents.
  /// Round the stored total by the same scaled-integer rule used by Dart/Go
  /// accounting. Conflicting complete allocations retain the original display:
  /// choosing their sum would hide the separate client/server accounting defect.
  static double billTotalForDisplay(
    double total, {
    Iterable<double> shares = const [],
  }) {
    if (!total.isFinite || total < 0 || total * 100 > 9007199254740991) {
      return total;
    }
    final rounded = (total * 100).round() / 100;
    var cents = 0;
    var count = 0;
    for (final share in shares) {
      if (!share.isFinite || share < 0) return total;
      final shareCents = (share * 100).round();
      final shareNoise = 4 * 2.220446049250313e-16 * (share > 1 ? share : 1);
      if ((share - shareCents / 100).abs() > shareNoise) return total;
      cents += shareCents;
      count++;
    }
    // Four binary64 ULPs cover summation/serialization noise, including at the
    // API's 1e9 money limit; this is not an extra monetary tolerance.
    final noise = 4 * 2.220446049250313e-16 * (total > 1 ? total : 1);
    if (count > 0 &&
        cents != (total * 100).round() &&
        (cents / 100 - total).abs() <= 0.01 + noise) {
      return total;
    }
    return rounded;
  }

  static String formatBillTotal(
    double total, {
    String currencyCode = 'USD',
    Iterable<double> shares = const [],
  }) => formatCurrency(
    billTotalForDisplay(total, shares: shares),
    currencyCode: currencyCode,
  );

  static String formatCurrency(double value, {String currencyCode = 'USD'}) {
    final code = currencyCode.trim().toUpperCase();
    final prefix = code == 'USD' ? '\$' : '$code ';
    return '$prefix${value.toStringAsFixed(2)}';
  }
}
