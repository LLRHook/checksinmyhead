import 'dart:convert';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:flutter/material.dart';

class RecentBillModel {
  final int id;
  final List<String> participantNames;
  final int participantCount;
  final double total;
  final DateTime date;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double tipPercentage;
  final List<Map<String, dynamic>>? items;
  final Color color;
  final Map<String, Map<String, double>>? itemAssignments;

  RecentBillModel({
    required this.id,
    required this.participantNames,
    required this.participantCount,
    required this.total,
    required this.date,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    this.tipPercentage = 0,
    this.items,
    required this.color,
    this.itemAssignments,
  });

  factory RecentBillModel.fromData(RecentBill data) {
    // Parse participant names from JSON
    List<String> names = [];
    try {
      final List<dynamic> decoded = jsonDecode(data.participants);
      names = decoded.cast<String>();
    } catch (e) {
      debugPrint('Error parsing participants: $e');
    }

    List<Map<String, dynamic>>? itemsList;
    Map<String, Map<String, double>>? assignmentsMap;
    if (data.items != null) {
      try {
        final List<dynamic> decodedItems = jsonDecode(data.items!);
        itemsList = decodedItems.cast<Map<String, dynamic>>();
        // Extract assignments from items
        assignmentsMap = {};
        for (var item in itemsList) {
          final itemName = item['name'] as String? ?? 'Unknown Item';
          final assignments = item['assignments'] as Map<String, dynamic>?;
          if (assignments != null) {
            Map<String, double> personAssignments = {};
            assignments.forEach((personName, percentage) {
              if (percentage is num) {
                personAssignments[personName] = percentage.toDouble();
              }
            });
            if (personAssignments.isNotEmpty) {
              assignmentsMap[itemName] = personAssignments;
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing items: $e');
      }
    }

    // Parse date
    DateTime billDate;
    try {
      billDate = DateTime.parse(data.date);
    } catch (e) {
      billDate = data.createdAt; // Fallback to createdAt
    }

    // Calculate tip percentage if not stored
    double tipPercentage = 0;
    if (data.tipPercentage != null) {
      // Use stored value if available
      tipPercentage = data.tipPercentage!;
    } else if (data.subtotal > 0) {
      // Calculate if not available
      tipPercentage = (data.tipAmount / data.subtotal) * 100;
    }

    return RecentBillModel(
      id: data.id,
      participantNames: names,
      participantCount: data.participantCount,
      total: data.total,
      date: billDate,
      subtotal: data.subtotal,
      tax: data.tax,
      tipAmount: data.tipAmount,
      tipPercentage: tipPercentage,
      items: itemsList,
      itemAssignments: assignmentsMap,
      color: Color(data.colorValue),
    );
  }

  // Format date as a readable string
  String get formattedDate {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Get first few participant names for display
  String get participantSummary {
    if (participantNames.isEmpty) return 'No participants';
    if (participantNames.length <= 2) {
      return participantNames.join(' & ');
    }
    return '${participantNames[0]}, ${participantNames[1]} & ${participantCount - 2} more';
  }

  // Get participants as Person objects
  List<Person> get participants {
    debugPrint(
      "DEBUG: Getting participants - count: ${participantNames.length}",
    );
    return participantNames
        .map((name) => Person(name: name, color: color))
        .toList();
  }

  // Generate bill items from saved data
  List<BillItem> getBillItems() {
    if (items == null) {
      debugPrint("DEBUG: No items found in bill");
      return [];
    }

    debugPrint("DEBUG: Generating ${items!.length} bill items");

    final billItems =
        items!.map((itemData) {
          final name = itemData['name'] as String? ?? 'Unknown Item';
          final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
          final assignments = itemData['assignments'] as Map<String, dynamic>?;

          // Convert string-based assignments to Person-based assignments
          Map<Person, double> personAssignments = {};
          if (assignments != null) {
            debugPrint(
              "DEBUG: Item $name has ${assignments.length} assignments",
            );
            assignments.forEach((personName, percentage) {
              if (percentage is num && percentage > 0) {
                personAssignments[Person(name: personName, color: color)] =
                    percentage.toDouble();
                debugPrint(
                  "DEBUG: Assigned $personName: ${percentage.toDouble()}% of $name",
                );
              }
            });
          } else {
            debugPrint("DEBUG: Item $name has no assignments");
          }

          return BillItem(
            name: name,
            price: price,
            assignments: personAssignments,
          );
        }).toList();

    debugPrint("DEBUG: Generated ${billItems.length} bill items");
    return billItems;
  }

  // Generate person shares from bill data
  Map<Person, double> generatePersonShares() {
    debugPrint("DEBUG: Generating person shares");

    // Create persons from names
    List<Person> personList = participants;
    Map<Person, double> shares = {};

    // Case 1: If we have items with assignments, calculate shares
    if (items != null && items!.isNotEmpty) {
      debugPrint("DEBUG: Bill has ${items!.length} items");

      // Initialize all shares with zero
      for (Person person in personList) {
        shares[person] = 0.0;
      }

      // Get bill items with proper assignments
      List<BillItem> billItems = getBillItems();

      // Calculate item amounts for each person
      for (var item in billItems) {
        debugPrint("DEBUG: Processing item ${item.name} (${item.price})");
        debugPrint("DEBUG: Item has ${item.assignments.length} assignments");

        item.assignments.forEach((person, percentage) {
          final amount = item.price * percentage / 100;
          debugPrint(
            "DEBUG: ${person.name} pays ${percentage}% = $amount for ${item.name}",
          );

          shares.update(
            Person(name: person.name, color: color),
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        });
      }

      // Calculate tax and tip proportionally
      final double totalTaxAndTip = tax + tipAmount;
      debugPrint("DEBUG: Total tax and tip: $totalTaxAndTip");

      // Get the sum of all item costs
      final double itemTotal = billItems.fold(
        0.0,
        (sum, item) => sum + item.price,
      );
      debugPrint("DEBUG: Item total: $itemTotal");

      // If there are actual assignments (not empty)
      if (shares.values.any((v) => v > 0)) {
        debugPrint("DEBUG: Found real assignments");

        // Calculate tax and tip proportionally to item amounts
        final calculatedTotal = shares.entries.fold(
          0.0,
          (sum, entry) => sum + entry.value,
        );
        debugPrint("DEBUG: Calculated total from shares: $calculatedTotal");

        if (calculatedTotal > 0) {
          // Distribute tax & tip proportionally to what each person is paying
          shares.forEach((person, amount) {
            final proportion = amount / calculatedTotal;
            final taxTipPortion = proportion * totalTaxAndTip;
            debugPrint(
              "DEBUG: ${person.name} pays $proportion of tax/tip = $taxTipPortion",
            );

            shares[person] = amount + taxTipPortion;
          });
        }
      } else {
        debugPrint("DEBUG: No real assignments, using equal shares");
        // Equal distribution if no specific assignments
        final equalShare = total / personList.length;
        for (Person person in personList) {
          shares[person] = equalShare;
          debugPrint("DEBUG: Equal share for ${person.name}: $equalShare");
        }
      }
    } else {
      debugPrint("DEBUG: No items, using equal shares");
      // Case 2: No items, so divide equally
      final equalShare = total / personList.length;
      for (Person person in personList) {
        shares[person] = equalShare;
        debugPrint("DEBUG: Equal share for ${person.name}: $equalShare");
      }
    }

    // Log final shares
    shares.forEach((person, amount) {
      debugPrint("DEBUG: FINAL SHARE: ${person.name} = $amount");
    });

    return shares;
  }
}
