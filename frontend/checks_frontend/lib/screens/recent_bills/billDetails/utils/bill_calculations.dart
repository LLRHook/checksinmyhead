import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';

/// Utility class to handle all bill-related calculations
class BillCalculations {
  final RecentBillModel bill;

  /// Cache for calculation results
  Map<String, double>? _personItemTotals;
  Map<String, double>? _personTaxAndTip;
  Map<String, double>? _personTotals;

  BillCalculations(this.bill);

  /// Generate the person shares map from bill data
  Map<Person, double> generatePersonShares() {
    Map<Person, double> shares = {};

    // In a real app, we'd have the actual shares saved in the database
    // Here we're just creating shares based on calculated totals
    if (bill.participantNames.isNotEmpty) {
      final personTotals = calculatePersonTotals();

      for (String name in bill.participantNames) {
        final amount =
            personTotals[name] ?? (bill.total / bill.participantNames.length);
        shares[Person(name: name, color: bill.color)] = amount;
      }
    }

    return shares;
  }

  /// Generate bill items from saved data
  List<BillItem> generateBillItems() {
    List<BillItem> items = [];

    // Convert the saved items data to BillItem objects
    if (bill.items != null) {
      for (var itemData in bill.items!) {
        final name = itemData['name'] as String? ?? 'Unknown Item';
        final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
        final isAlcohol = itemData['isAlcohol'] as bool? ?? false;
        final assignments = itemData['assignments'] as Map<String, dynamic>?;

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

        // Create a BillItem with all available data
        items.add(
          BillItem(
            name: name,
            price: price,
            isAlcohol: isAlcohol,
            assignments: personAssignments,
          ),
        );
      }
    }

    return items;
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

    // If we don't have items or assignments, return equal shares
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

  /// Calculate tax and tip portions for each person
  Map<String, double> calculatePersonTaxAndTip() {
    // Return cached result if available
    if (_personTaxAndTip != null) {
      return _personTaxAndTip!;
    }

    Map<String, double> results = {};
    final personItemTotals = calculatePersonItemTotals();

    // Calculate the total item sum that was assigned
    final double assignedItemsTotal = personItemTotals.values.fold(
      0.0,
      (sum, value) => sum + value,
    );

    // If no items were assigned, distribute tax and tip equally
    if (assignedItemsTotal <= 0 || personItemTotals.isEmpty) {
      final equalShare =
          (bill.tax + bill.tipAmount) / bill.participantNames.length;

      for (final name in bill.participantNames) {
        results[name] = equalShare;
      }

      _personTaxAndTip = results;
      return results;
    }

    // Calculate each person's proportion of the total
    for (final entry in personItemTotals.entries) {
      final proportion = entry.value / assignedItemsTotal;
      // Assign tax and tip proportionally
      results[entry.key] = proportion * (bill.tax + bill.tipAmount);
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

    // Combine item amounts with tax and tip
    for (final name in bill.participantNames) {
      totals[name] = (itemTotals[name] ?? 0.0) + (taxAndTipTotals[name] ?? 0.0);
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
