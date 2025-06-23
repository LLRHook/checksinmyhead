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

import 'dart:convert';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:flutter/material.dart';

/// RecentBillModel
///
/// A model class that represents a saved bill retrieved from persistent storage.
/// This class encapsulates all the data associated with a bill, including financial
/// information, participants, items, assignments, and display properties.
///
/// The model provides methods to:
/// - Parse raw database data into a usable model object
/// - Format bill data for display
/// - Generate derived data such as participant lists and bill item assignments
/// - Calculate share amounts for each person
///
/// This model serves as the core data structure for displaying and manipulating
/// saved bills throughout the bill history and detail screens.
class RecentBillModel {
  /// Unique identifier for the bill
  final int id;

  /// Name of the bill for display purposes
  final String billName;

  /// List of participant names
  final List<String> participantNames;

  /// Number of participants in the bill
  final int participantCount;

  /// Total bill amount (subtotal + tax + tip)
  final double total;

  /// Date when the bill was created/saved
  final DateTime date;

  /// Sum of all item prices before tax and tip
  final double subtotal;

  /// Tax amount applied to the bill
  final double tax;

  /// Tip amount added to the bill
  final double tipAmount;

  /// Tip percentage relative to subtotal
  final double tipPercentage;

  /// List of individual bill items with prices and assignments
  final List<Map<String, dynamic>>? items;

  /// Theme color associated with this bill
  final Color color;

  /// Map of item names to person assignments with percentages
  final Map<String, Map<String, double>>? itemAssignments;

  RecentBillModel({
    required this.id,
    this.billName = '',
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

  /// Creates a RecentBillModel from raw database data
  ///
  /// This factory method parses the database record into a structured model,
  /// handling JSON deserialization, type conversions, and default values.
  ///
  /// Parameters:
  /// - data: Raw RecentBill database object
  ///
  /// Returns:
  /// - A properly formatted RecentBillModel with all fields populated
  factory RecentBillModel.fromData(RecentBill data) {
    // Parse participant names from JSON string
    List<String> names = [];
    try {
      final List<dynamic> decoded = jsonDecode(data.participants);
      names = decoded.cast<String>();
    } catch (e) {
      debugPrint('Error parsing participants: $e');
    }

    // Parse items and assignments from JSON if available
    List<Map<String, dynamic>>? itemsList;
    Map<String, Map<String, double>>? assignmentsMap;
    if (data.items != null) {
      try {
        // Parse items array
        final List<dynamic> decodedItems = jsonDecode(data.items!);
        itemsList = decodedItems.cast<Map<String, dynamic>>();

        // Extract item assignments into a more accessible structure
        assignmentsMap = {};
        for (var item in itemsList) {
          final itemName = item['name'] as String? ?? 'Unknown Item';
          final assignments = item['assignments'] as Map<String, dynamic>?;

          if (assignments != null) {
            Map<String, double> personAssignments = {};
            assignments.forEach((personName, percentage) {
              // Convert percentage to double (handles both int and double values)
              if (percentage is num) {
                personAssignments[personName] = percentage.toDouble();
              }
            });

            // Only add to map if there are actual assignments
            if (personAssignments.isNotEmpty) {
              assignmentsMap[itemName] = personAssignments;
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing items: $e');
      }
    }

    // Parse date with fallback to creation timestamp
    DateTime billDate;
    try {
      billDate = DateTime.parse(data.date);
    } catch (e) {
      billDate = data.createdAt; // Use database creation timestamp as fallback
    }

    // Calculate or retrieve tip percentage
    double tipPercentage = 0;
    if (data.tipPercentage != null) {
      // Use stored value if available from newer database records
      tipPercentage = data.tipPercentage!;
    } else if (data.subtotal > 0) {
      // Calculate for older records that might not have the field
      tipPercentage = (data.tipAmount / data.subtotal) * 100;
    }

    // Construct and return the model
    return RecentBillModel(
      id: data.id,
      billName: data.billName,
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
      color: Color(data.colorValue), // Convert stored integer to Color
    );
  }

  /// Formats the date in a readable MM/DD/YYYY format
  ///
  /// This getter provides a consistent date format for display throughout the app.
  String get formattedDate {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Returns a condensed summary of participants for display
  ///
  /// This method creates a user-friendly string showing the first few participants
  /// and a count of remaining participants if there are more than can be displayed.
  ///
  /// Format examples:
  /// - "No participants" (if empty)
  /// - "John & Mary" (if 2 or fewer)
  /// - "John, Mary & 3 more" (if more than 2)
  String get participantSummary {
    if (participantNames.isEmpty) return 'No participants';

    // For 1-2 participants, show all names
    if (participantNames.length <= 2) {
      return participantNames.join(' & ');
    }

    // For 3+ participants, show first two and a count of others
    return '${participantNames[0]}, ${participantNames[1]} & ${participantCount - 2} more';
  }

  /// Converts participant names to Person objects
  ///
  /// This getter creates a list of Person objects from the stored names,
  /// applying the bill's color to each person for consistent styling.
  List<Person> get participants {
    return participantNames
        .map((name) => Person(name: name, color: color))
        .toList();
  }

  /// Generates bill items from the saved data
  ///
  /// This method reconstructs BillItem objects from the stored JSON data,
  /// including their assignments to people.
  ///
  /// Returns:
  /// - A list of BillItem objects with their prices and assignments
  /// - Empty list if no items are available
  List<BillItem> getBillItems() {
    if (items == null) {
      return [];
    }

    final billItems =
        items!.map((itemData) {
          // Extract item properties with fallbacks for missing data
          final name = itemData['name'] as String? ?? 'Unknown Item';
          final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
          final assignments = itemData['assignments'] as Map<String, dynamic>?;

          // Convert string-based assignments to Person-based assignments
          Map<Person, double> personAssignments = {};
          if (assignments != null) {
            assignments.forEach((personName, percentage) {
              // Only include positive percentages
              if (percentage is num && percentage > 0) {
                // Create Person object with consistent color
                personAssignments[Person(name: personName, color: color)] =
                    percentage.toDouble();
              }
            });
          }

          // Create and return the bill item
          return BillItem(
            name: name,
            price: price,
            assignments: personAssignments,
          );
        }).toList();

    return billItems;
  }

  /// Calculates each person's share of the bill
  ///
  /// This method determines how much each participant should pay based on their
  /// item assignments, including their proportional share of tax and tip.
  ///
  /// The calculation logic:
  /// 1. If items with assignments exist:
  ///    a. Calculate each person's share of item costs
  ///    b. Distribute tax and tip proportionally
  /// 2. If no items or no assignments:
  ///    a. Split the total bill equally among all participants
  ///
  /// Returns:
  /// - A map of Person objects to their calculated share amounts
  Map<Person, double> generatePersonShares() {
    // Create Person objects from participant names
    List<Person> personList = participants;
    Map<Person, double> shares = {};

    // Case 1: If we have items with assignments, calculate shares based on them
    if (items != null && items!.isNotEmpty) {
      // Initialize all shares with zero
      for (Person person in personList) {
        shares[person] = 0.0;
      }

      // Get bill items with their assignments
      List<BillItem> billItems = getBillItems();

      // Calculate item amounts for each person based on their assigned percentages
      for (var item in billItems) {
        item.assignments.forEach((person, percentage) {
          // Calculate this person's amount for this item
          final amount = item.price * percentage / 100;

          // Add to person's running total (or create entry if first item)
          shares.update(
            Person(name: person.name, color: color),
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        });
      }

      // Calculate the total tax and tip amount
      final double totalTaxAndTip = tax + tipAmount;

      // Check if there are any actual assignments (non-zero shares)
      if (shares.values.any((v) => v > 0)) {
        // Calculate total from assigned shares
        final calculatedTotal = shares.entries.fold(
          0.0,
          (sum, entry) => sum + entry.value,
        );

        if (calculatedTotal > 0) {
          // Distribute tax & tip proportionally to what each person is paying for items
          shares.forEach((person, amount) {
            // Calculate proportion of item costs
            final proportion = amount / calculatedTotal;

            // Apply that proportion to tax and tip
            final taxTipPortion = proportion * totalTaxAndTip;

            // Add tax/tip portion to their item costs
            shares[person] = amount + taxTipPortion;
          });
        }
      } else {
        // Equal distribution if no specific assignments exist
        final equalShare = total / personList.length;
        for (Person person in personList) {
          shares[person] = equalShare;
        }
      }
    } else {
      // Case 2: No items, so divide equally
      final equalShare = total / personList.length;
      for (Person person in personList) {
        shares[person] = equalShare;
      }
    }

    return shares;
  }
}
