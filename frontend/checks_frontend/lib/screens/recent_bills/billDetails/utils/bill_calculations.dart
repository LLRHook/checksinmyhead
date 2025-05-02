import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';

/// Utility class to handle all bill-related calculations
class BillCalculations {
  final RecentBillModel bill;

  /// Cache for calculation results
  Map<String, double>? _personItemTotals;
  Map<String, double>? _personTaxAndTip;
  Map<String, double>? _personAlcoholCharges;
  Map<String, double>? _personTotals;

  BillCalculations(this.bill);

  /// Generate the person shares map from bill data
  Map<Person, double> generatePersonShares() {
    final personTotals = calculatePersonTotals();
    Map<Person, double> shares = {};

    for (String name in bill.participantNames) {
      final amount =
          personTotals[name] ?? (bill.total / bill.participantNames.length);
      shares[Person(name: name, color: bill.color)] = amount;
    }

    return shares;
  }

  /// Generate bill items from saved data
  List<BillItem> generateBillItems() {
    if (bill.items == null) return [];

    return bill.items!.map((itemData) {
      final name = itemData['name'] as String? ?? 'Unknown Item';
      final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
      final isAlcohol = itemData['isAlcohol'] as bool? ?? false;
      final assignments = itemData['assignments'] as Map<String, dynamic>?;

      // Get alcohol tax and tip from saved data
      final alcoholTaxPortion =
          isAlcohol
              ? (itemData['alcoholTaxPortion'] as num?)?.toDouble()
              : null;
      final alcoholTipPortion =
          isAlcohol
              ? (itemData['alcoholTipPortion'] as num?)?.toDouble()
              : null;

      // Convert string-based assignments to Person-based assignments
      Map<Person, double> personAssignments = {};
      if (assignments != null) {
        assignments.forEach((personName, percentage) {
          if (percentage is num && percentage > 0) {
            personAssignments[Person(name: personName, color: bill.color)] =
                percentage.toDouble();
          }
        });
      }

      return BillItem(
        name: name,
        price: price,
        isAlcohol: isAlcohol,
        assignments: personAssignments,
        alcoholTaxPortion: alcoholTaxPortion,
        alcoholTipPortion: alcoholTipPortion,
      );
    }).toList();
  }

  /// Calculate alcohol charges for each person
  Map<String, double> calculatePersonAlcoholCharges() {
    // Return cached result if available
    if (_personAlcoholCharges != null) {
      return _personAlcoholCharges!;
    }

    Map<String, double> alcoholCharges = {};

    // Initialize with zero for all participants
    for (final name in bill.participantNames) {
      alcoholCharges[name] = 0.0;
    }

    // If no items or no alcohol items, return zeros
    if (bill.items == null || bill.items!.isEmpty) {
      _personAlcoholCharges = alcoholCharges;
      return alcoholCharges;
    }

    // Calculate alcohol charges for each person
    for (final item in bill.items!) {
      final isAlcohol = item['isAlcohol'] as bool? ?? false;

      if (isAlcohol) {
        final assignments = item['assignments'] as Map<String, dynamic>?;
        final alcoholTaxPortion =
            (item['alcoholTaxPortion'] as num?)?.toDouble() ?? 0.0;
        final alcoholTipPortion =
            (item['alcoholTipPortion'] as num?)?.toDouble() ?? 0.0;

        if (assignments != null &&
            (alcoholTaxPortion > 0 || alcoholTipPortion > 0)) {
          assignments.forEach((personName, percentage) {
            if (percentage is num && alcoholCharges.containsKey(personName)) {
              // Calculate this person's share of alcohol charges
              final share = percentage / 100.0;
              alcoholCharges[personName] =
                  (alcoholCharges[personName] ?? 0.0) +
                  (alcoholTaxPortion * share) +
                  (alcoholTipPortion * share);
            }
          });
        }
      }
    }

    _personAlcoholCharges = alcoholCharges;
    return alcoholCharges;
  }

  /// Calculate how much each person is assigned for items
  Map<String, double> calculatePersonItemTotals() {
    // Return cached result if available
    if (_personItemTotals != null) {
      return _personItemTotals!;
    }

    Map<String, double> personTotals = {};

    // Initialize with zero for all participants
    for (final name in bill.participantNames) {
      personTotals[name] = 0.0;
    }

    // If we don't have items or assignments, return zeros
    if (bill.items == null || bill.items!.isEmpty) {
      _personItemTotals = personTotals;
      return personTotals;
    }

    // Calculate each person's assigned items
    for (final item in bill.items!) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final assignments = item['assignments'] as Map<String, dynamic>?;

      if (assignments != null) {
        assignments.forEach((personName, percentage) {
          if (percentage is num && personTotals.containsKey(personName)) {
            // Add this item's portion to the person's total
            personTotals[personName] =
                (personTotals[personName] ?? 0.0) + (price * percentage / 100);
          }
        });
      }
    }

    _personItemTotals = personTotals;
    return personTotals;
  }

  /// Calculate regular tax and tip portions for each person
  Map<String, double> calculatePersonTaxAndTip() {
    // Return cached result if available
    if (_personTaxAndTip != null) {
      return _personTaxAndTip!;
    }

    Map<String, double> results = {};
    final personItemTotals = calculatePersonItemTotals();

    // Calculate the regular tax and tip (excluding alcohol-specific charges)
    final double regularTax = bill.tax - (bill.totalAlcoholTax ?? 0.0);
    final double regularTip = bill.tipAmount - (bill.totalAlcoholTip ?? 0.0);
    final double totalRegularTaxAndTip = regularTax + regularTip;

    // Calculate the total item sum that was assigned
    final double assignedItemsTotal = personItemTotals.values.fold(
      0.0,
      (sum, value) => sum + value,
    );

    // If no items were assigned, distribute tax and tip equally
    if (assignedItemsTotal <= 0 || personItemTotals.isEmpty) {
      final equalShare = totalRegularTaxAndTip / bill.participantNames.length;

      for (final name in bill.participantNames) {
        results[name] = equalShare;
      }
    } else {
      // Calculate each person's proportion of the total
      for (final entry in personItemTotals.entries) {
        final proportion =
            assignedItemsTotal > 0
                ? entry.value / assignedItemsTotal
                : 1.0 / bill.participantNames.length;

        // Assign tax and tip proportionally
        results[entry.key] = proportion * totalRegularTaxAndTip;
      }
    }

    _personTaxAndTip = results;
    return results;
  }

  /// Get the total cost for each person
  Map<String, double> calculatePersonTotals() {
    // Return cached result if available
    if (_personTotals != null) {
      return _personTotals!;
    }

    Map<String, double> totals = {};
    final itemTotals = calculatePersonItemTotals();
    final taxAndTipTotals = calculatePersonTaxAndTip();
    final alcoholCharges = calculatePersonAlcoholCharges();

    // Combine all components for each person
    for (final name in bill.participantNames) {
      final itemAmount = itemTotals[name] ?? 0.0;
      final taxTipAmount = taxAndTipTotals[name] ?? 0.0;
      final alcoholAmount = alcoholCharges[name] ?? 0.0;

      // Make sure we're adding all three components
      totals[name] = itemAmount + taxTipAmount + alcoholAmount;
    }

    _personTotals = totals;
    return totals;
  }

  /// Check if the bill has real item assignments (not just equal shares)
  bool hasRealAssignments() {
    return calculatePersonItemTotals().values.any((v) => v > 0);
  }

  /// Calculate the equal share per person
  double calculateEqualShare() {
    return bill.total / (bill.participantCount > 0 ? bill.participantCount : 1);
  }
}
