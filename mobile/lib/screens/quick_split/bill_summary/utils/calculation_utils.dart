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

import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/assignment_utils.dart';

/// CalculationUtils - Utility for calculating individual bill payments
///
/// Calculates each person's portion of a bill (subtotal, tax, tip, total)
/// based on either itemized assignments or proportional shares.
///
/// Inputs:
///   - person: Person to calculate for
///   - participants: All people involved in the bill
///   - personShares: Map of each person to their share amount
///   - items: Bill items with person assignments (optional)
///   - subtotal, tax, tipAmount: Bill totals
///   - birthdayPerson: Person receiving special birthday handling (optional)
///
/// Returns: Map with 'subtotal', 'tax', 'tip', and 'total' amounts
class CalculationUtils {
  static Map<String, double> calculatePersonAmounts({
    required Person person,
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required Person? birthdayPerson,
  }) {
    double personSubtotal = 0.0;

    if (items.isNotEmpty) {
      // Itemized approach: Sum costs of items assigned to this person
      for (var item in items) {
        personSubtotal += item.amountForPerson(person);
      }
    } else {
      // Proportional approach based on person's share
      final personTotal = personShares[person] ?? 0.0;
      final totalWithoutExtras = subtotal;
      final extras = tax + tipAmount;

      // Special case: birthday person or anyone with $0 share
      if (personTotal <= 0) {
        return {'subtotal': 0.0, 'tax': 0.0, 'tip': 0.0, 'total': 0.0};
      }

      final proportion = personTotal / (totalWithoutExtras + extras);
      personSubtotal = proportion * totalWithoutExtras;
    }

    // Calculate tax and tip proportionally to subtotal
    final proportion = subtotal > 0 ? personSubtotal / subtotal : 0.0;
    final personTax = tax * proportion;
    final personTip = tipAmount * proportion;

    return {
      'subtotal': personSubtotal,
      'tax': personTax,
      'tip': personTip,
      'total': personSubtotal + personTax + personTip,
    };
  }

  /// Calculates amounts for all participants and applies largest-remainder
  /// correction so that per-person totals sum to the exact bill total.
  ///
  /// This wraps [calculatePersonAmounts] for each participant and then
  /// redistributes fractional cents using Hamilton's method.
  static Map<Person, Map<String, double>> calculateAllPersonAmounts({
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    required Person? birthdayPerson,
  }) {
    // First, calculate raw amounts for each person
    final rawAmounts = <Person, Map<String, double>>{};
    final rawTotals = <Person, double>{};

    for (final person in participants) {
      final amounts = calculatePersonAmounts(
        person: person,
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: subtotal,
        tax: tax,
        tipAmount: tipAmount,
        birthdayPerson: birthdayPerson,
      );
      rawAmounts[person] = amounts;
      rawTotals[person] = amounts['total']!;
    }

    // Apply largest-remainder correction on the totals
    final correctedTotals = AssignmentUtils.applyLargestRemainder(rawTotals, total);

    // Merge corrected totals back into per-person maps
    final result = <Person, Map<String, double>>{};
    for (final person in participants) {
      final raw = rawAmounts[person]!;
      result[person] = {
        'subtotal': raw['subtotal']!,
        'tax': raw['tax']!,
        'tip': raw['tip']!,
        'total': correctedTotals[person]!,
      };
    }

    return result;
  }

}
