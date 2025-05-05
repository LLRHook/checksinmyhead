import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';

/// BillCalculations
///
/// A comprehensive utility class that handles all bill-related calculations for a given bill.
/// This class is responsible for generating person shares, calculating item totals,
/// determining tax and tip distributions, and providing various bill analytics.
///
/// The class implements caching for performance optimization, storing calculation results
/// to avoid redundant computations when the same data is requested multiple times.
///
/// Key responsibilities:
/// - Converting bill data into person-specific payment amounts
/// - Calculating how items, tax, and tip are distributed among participants
/// - Generating BillItem objects from serialized bill data
/// - Providing utility methods for bill analysis (equal shares, assignment verification)
///
/// All monetary values are handled as double and represent currency amounts.
class BillCalculations {
  final RecentBillModel bill;

  /// Cache for calculation results to avoid redundant calculations
  /// These are lazily initialized and stored for the lifetime of this object
  Map<String, double>?
  _personItemTotals; // Person name -> sum of their assigned item costs
  Map<String, double>?
  _personTaxAndTip; // Person name -> their portion of tax and tip
  Map<String, double>?
  _personTotals; // Person name -> their total bill share (items + tax/tip)

  /// Constructor that takes a RecentBillModel as input
  BillCalculations(this.bill);

  /// Generates a mapping of Person objects to their total bill shares
  ///
  /// This method creates Person objects from the bill's participant names
  /// and associates each person with their calculated total amount to pay.
  ///
  /// Returns:
  /// - A Map where keys are Person objects and values are the total amounts each person owes
  ///
  /// Note: If calculations fail for a participant, they will be assigned an equal share of the total
  Map<Person, double> generatePersonShares() {
    final personTotals = calculatePersonTotals();
    Map<Person, double> shares = {};

    for (String name in bill.participantNames) {
      // Use calculated amount or fall back to equal share if calculation failed
      final amount =
          personTotals[name] ?? (bill.total / bill.participantNames.length);

      // Create a Person object with name and the bill's color
      shares[Person(name: name, color: bill.color)] = amount;
    }

    return shares;
  }

  /// Converts serialized bill item data into BillItem objects
  ///
  /// This method transforms the raw item data (typically from JSON or database)
  /// into proper BillItem objects with their associated person assignments.
  ///
  /// Returns:
  /// - A List of BillItem objects reconstructed from the bill data
  /// - Empty list if no items are found in the bill
  List<BillItem> generateBillItems() {
    if (bill.items == null) return [];

    return bill.items!.map((itemData) {
      // Extract item properties with fallbacks for data integrity
      final name = itemData['name'] as String? ?? 'Unknown Item';
      final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
      final assignments = itemData['assignments'] as Map<String, dynamic>?;

      // Convert string-based assignments to Person-based assignments
      // This translates from {personName: percentageValue} to {Person: percentageValue}
      Map<Person, double> personAssignments = {};
      if (assignments != null) {
        assignments.forEach((personName, percentage) {
          // Only include valid percentage assignments (must be numeric and positive)
          if (percentage is num && percentage > 0) {
            personAssignments[Person(name: personName, color: bill.color)] =
                percentage.toDouble();
          }
        });
      }

      return BillItem(name: name, price: price, assignments: personAssignments);
    }).toList();
  }

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
      final equalShare = totalTaxAndTip / bill.participantNames.length;

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
