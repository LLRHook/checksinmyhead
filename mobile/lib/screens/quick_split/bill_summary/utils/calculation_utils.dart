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

import '/models/person.dart';
import '/models/bill_item.dart';

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
    final proportion = personSubtotal / subtotal;
    final personTax = tax * proportion;
    final personTip = tipAmount * proportion;

    return {
      'subtotal': personSubtotal,
      'tax': personTax,
      'tip': personTip,
      'total': personSubtotal + personTax + personTip,
    };
  }
}
