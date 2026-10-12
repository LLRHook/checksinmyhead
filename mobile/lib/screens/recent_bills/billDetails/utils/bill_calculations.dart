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

import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';

class BillCalculations {
  final RecentBillModel bill;

  Map<String, double>?
  _personItemTotals; // Person name -> sum of their assigned item costs
  Map<String, double>?
  _personTaxAndTip; // Person name -> their portion of tax and tip
  Map<String, double>?
  _personTotals; // Person name -> their total bill share (items + tax/tip)

  BillCalculations(this.bill);

  /// Calculates the total cost of items assigned to each person
  ///
  /// This method determines how much each person is responsible for
  /// based solely on the item assignments (before tax and tip).
  ///
  /// Returns:
  /// - A Map where keys are person names and values are their item totals
  /// - If no items exist, returns a map with zeros for all participants
  ///
  /// Note: Results are cached for performance optimization
  Map<String, double> calculatePersonItemTotals() {
    // Return cached result if available to avoid recalculation
    if (_personItemTotals != null) {
      return _personItemTotals!;
    }

    Map<String, double> personTotals = {};

    // Initialize with zero for all participants to ensure all participants are included
    for (final name in bill.participantNames) {
      personTotals[name] = 0.0;
    }

    // If we don't have items or assignments, return zeros for everyone
    if (bill.items == null || bill.items!.isEmpty) {
      _personItemTotals = personTotals;
      return personTotals;
    }

    // Calculate each person's assigned items by iterating through all bill items
    for (final item in bill.items!) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final assignments = item['assignments'] as Map<String, dynamic>?;

      if (assignments != null) {
        assignments.forEach((personName, percentage) {
          if (percentage is num && personTotals.containsKey(personName)) {
            // Add this item's portion to the person's total
            // The percentage is stored as a value from 0-100, so we divide by 100
            personTotals[personName] =
                (personTotals[personName] ?? 0.0) + (price * percentage / 100);
          }
        });
      }
    }

    // Cache the result for future use
    _personItemTotals = personTotals;
    return personTotals;
  }

  /// Calculates how tax and tip should be distributed among participants
  ///
  /// This method distributes the tax and tip proportionally based on
  /// each person's portion of the assigned items. If no items are assigned,
  /// tax and tip are distributed equally.
  ///
  /// Returns:
  /// - A Map where keys are person names and values are their tax and tip portions
  ///
  /// Note: Results are cached for performance optimization
  Map<String, double> calculatePersonTaxAndTip() {
    // Return cached result if available
    if (_personTaxAndTip != null) {
      return _personTaxAndTip!;
    }

    Map<String, double> results = {};
    final personItemTotals = calculatePersonItemTotals();

    // Total amount to distribute (tax + tip combined)
    final double totalTaxAndTip = bill.tax + bill.tipAmount;

    // Calculate the total item sum that was assigned to determine proportions
    final double assignedItemsTotal = personItemTotals.values.fold(
      0.0,
      (sum, value) => sum + value,
    );

    // If no items were assigned or sum is zero, distribute tax and tip equally
    if (assignedItemsTotal <= 0 || personItemTotals.isEmpty) {
      final equalShare =
          bill.participantNames.isNotEmpty
              ? totalTaxAndTip / bill.participantNames.length
              : 0.0;

      for (final name in bill.participantNames) {
        results[name] = equalShare;
      }
    } else {
      // Calculate each person's proportion of the total based on their item assignments
      for (final entry in personItemTotals.entries) {
        // Calculate proportion (or default to equal share if items total is somehow 0)
        final proportion =
            assignedItemsTotal > 0
                ? entry.value / assignedItemsTotal
                : 1.0 / bill.participantNames.length;

        // Assign tax and tip proportionally based on their item amounts
        results[entry.key] = proportion * totalTaxAndTip;
      }
    }

    // Cache the result for future use
    _personTaxAndTip = results;
    return results;
  }

  /// Calculates the complete total amount each person should pay
  ///
  /// This combines the item totals with tax and tip portions for each person
  /// to determine their final payment amount.
  ///
  /// Returns:
  /// - A Map where keys are person names and values are their complete bill shares
  ///
  /// Note: Results are cached for performance optimization
  Map<String, double> calculatePersonTotals() {
    // Return cached result if available
    if (_personTotals != null) {
      return _personTotals!;
    }

    Map<String, double> totals = {};
    final itemTotals = calculatePersonItemTotals();
    final taxAndTipTotals = calculatePersonTaxAndTip();

    // Combine all components for each person (items + their portion of tax/tip)
    for (final name in bill.participantNames) {
      final itemAmount = itemTotals[name] ?? 0.0;
      final taxTipAmount = taxAndTipTotals[name] ?? 0.0;

      // Total amount = assigned items + portion of tax & tip
      totals[name] = itemAmount + taxTipAmount;
    }

    // Cache the result for future use
    _personTotals = totals;
    return totals;
  }

  /// Determines if the bill has explicit item assignments or just equal shares
  ///
  /// This utility method checks if any items have been specifically assigned to participants,
  /// which is useful for determining whether to show detailed breakdowns or simplified views.
  ///
  /// Returns:
  /// - true if at least one person has items specifically assigned to them
  /// - false if no real assignments exist (indicating equal splits)
  bool hasRealAssignments() {
    return calculatePersonItemTotals().values.any((v) => v > 0);
  }

  /// Calculates what each person would pay in a simple equal split
  ///
  /// This provides the amount each person would pay if the bill were split equally,
  /// regardless of the actual item assignments.
  ///
  /// Returns:
  /// - The equal share amount per person (total bill ÷ number of participants)
  /// - If no participants exist, returns the total bill amount to avoid division by zero
  double calculateEqualShare() {
    return bill.total / (bill.participantCount > 0 ? bill.participantCount : 1);
  }
}
