import 'package:flutter/material.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import '../models/assignment_data.dart';

class AssignmentUtils {
  /// Get background color based on assignments
  static Color getAssignmentColor(BillItem item, Color defaultColor) {
    // If fully assigned to one person, use their color
    if (item.assignments.length == 1 &&
        item.assignments.values.first == 100.0) {
      return item.assignments.keys.first.color.withOpacity(0.2);
    }
    // If partially assigned, use a neutral color
    return defaultColor;
  }

  /// Check if a person is already assigned to an item
  static bool isPersonAssignedToItem(BillItem item, Person person) {
    return item.assignments.containsKey(person) &&
        item.assignments[person]! > 0;
  }

  /// Get all assigned people for an item
  static List<Person> getAssignedPeopleForItem(BillItem item) {
    return item.assignments.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
  }

  /// Balance an item between current assignees
  static Map<Person, double> balanceItemBetweenAssignees(
    BillItem item,
    List<Person> assignedPeople,
  ) {
    if (assignedPeople.isEmpty) return {};

    Map<Person, double> newAssignments = {};
    double percentage = 100.0 / assignedPeople.length;

    for (var person in assignedPeople) {
      newAssignments[person] = percentage;
    }

    return newAssignments;
  }

  /// Calculate a person's percentage of the total bill
  static double getPersonBillPercentage(Person person, AssignmentData data) {
    final total = data.total > 0 ? data.total : 1.0;
    final share = data.personFinalShares[person] ?? 0.0;
    return (share / total).clamp(0.0, 1.0);
  }

  /// Calculate initial assignments
  static AssignmentData calculateInitialAssignments(AssignmentData data) {
    Map<Person, double> personTotals = {};
    double unassignedAmount = 0.0;

    if (data.items.isEmpty) {
      // If no items were entered, split subtotal evenly
      // BUT we need to consider birthday person here
      int payingPeople = data.participants.length;
      if (data.birthdayPerson != null) payingPeople--;

      double evenShare =
          payingPeople > 0 ? data.subtotal / payingPeople : 0.0;

      for (var person in data.participants) {
        if (data.birthdayPerson == person) {
          personTotals[person] = 0.0; // Birthday person pays nothing
        } else {
          personTotals[person] = evenShare; // Everyone else pays more
        }
      }

      unassignedAmount = 0.0;
    } else {
      // If items were entered but not assigned, all amount is unassigned
      unassignedAmount = data.subtotal;

      for (var person in data.participants) {
        personTotals[person] = 0.0;
      }
    }

    // Calculate final shares based on updated person totals
    final personFinalShares = calculateFinalShares(
      data.copyWith(
        personTotals: personTotals,
        unassignedAmount: unassignedAmount,
      ),
    );

    // Return updated assignment data
    return data.copyWith(
      personTotals: personTotals,
      personFinalShares: personFinalShares,
      unassignedAmount: unassignedAmount,
    );
  }

  /// Calculate final shares based on person totals
  static Map<Person, double> calculateFinalShares(AssignmentData data) {
    Map<Person, double> newShares = {};

    // Calculate total assigned amount
    double totalAssigned = data.personTotals.values.fold(
      0,
      (sum, amount) => sum + amount,
    );

    // Calculate percentage of bill for each person (if anything is assigned)
    if (totalAssigned > 0) {
      for (var person in data.participants) {
        if (data.birthdayPerson == person) {
          // Birthday person pays nothing
          newShares[person] = 0.0;
          continue;
        }

        double personSubtotal = data.personTotals[person] ?? 0.0;
        // Adjust the percentage calculation to exclude the birthday person from the total
        double personPercentage = personSubtotal / totalAssigned;

        // Calculate person's share of tax and tip
        double personTax = data.tax * personPercentage;
        double personTip = data.tipAmount * personPercentage;

        // Add to final share
        newShares[person] = personSubtotal + personTax + personTip;
      }
    } else {
      // If nothing assigned yet, split everything evenly except for birthday person
      int payingPeople = data.participants.length;
      if (data.birthdayPerson != null) payingPeople--;

      if (payingPeople > 0) {
        double evenShare = data.total / payingPeople;

        for (var person in data.participants) {
          if (data.birthdayPerson == person) {
            newShares[person] = 0.0;
          } else {
            newShares[person] = evenShare;
          }
        }
      }
    }

    return newShares;
  }

  /// Assign an item to participants
  static AssignmentData assignItem(
    AssignmentData data,
    BillItem item,
    Map<Person, double> newAssignments,
  ) {
    // Update item assignments
    item.assignments = newAssignments;

    // Recalculate person totals
    Map<Person, double> newPersonTotals = {};
    for (var person in data.participants) {
      double personTotal = 0.0;

      // Sum all item assignments for this person
      for (var billItem in data.items) {
        personTotal += billItem.amountForPerson(person);
      }

      newPersonTotals[person] = personTotal;
    }

    // Calculate unassigned amount
    double assignedTotal = newPersonTotals.values.fold(
      0,
      (sum, amount) => sum + amount,
    );
    double unassignedAmount = data.subtotal - assignedTotal;

    // Calculate final shares based on updated person totals
    final personFinalShares = calculateFinalShares(
      data.copyWith(
        personTotals: newPersonTotals,
        unassignedAmount: unassignedAmount,
      ),
    );

    // Return updated assignment data
    return data.copyWith(
      personTotals: newPersonTotals,
      personFinalShares: personFinalShares,
      unassignedAmount: unassignedAmount,
    );
  }

  /// Evenly split an item among selected participants
  static Map<Person, double> splitItemEvenly(List<Person> people) {
    if (people.isEmpty) return {};

    Map<Person, double> newAssignments = {};
    double percentage = 100.0 / people.length;

    for (var person in people) {
      newAssignments[person] = percentage;
    }

    return newAssignments;
  }

  /// Unassign items from birthday person
  static AssignmentData unassignItemsFromBirthdayPerson(
    AssignmentData data,
    Person birthdayPerson,
  ) {
    // Keep track of changes to avoid unnecessary updates
    bool changesDetected = false;

    // Go through each item and remove the birthday person's assignments
    for (var item in data.items) {
      if (item.assignments.containsKey(birthdayPerson)) {
        // Get the percentage that was assigned to birthday person
        double birthdayPersonPercentage =
            item.assignments[birthdayPerson] ?? 0.0;

        if (birthdayPersonPercentage > 0) {
          changesDetected = true;

          // Remove the birthday person from assignments
          Map<Person, double> newAssignments = Map.from(item.assignments);
          newAssignments.remove(birthdayPerson);

          // If there are other people assigned to this item, redistribute
          if (newAssignments.isNotEmpty) {
            // Redistribute the percentage proportionally among remaining assignees
            double totalRemaining = newAssignments.values.fold(
              0.0,
              (sum, value) => sum + value,
            );

            if (totalRemaining > 0) {
              // Scale factor to redistribute
              double scaleFactor = 100.0 / totalRemaining;

              // Rescale everyone else's percentages
              newAssignments.forEach((key, value) {
                newAssignments[key] = value * scaleFactor;
              });
            }
          }

          // Update item assignments
          item.assignments = newAssignments;
        }
      }
    }

    if (changesDetected) {
      // Recalculate person totals if changes were made
      Map<Person, double> newPersonTotals = {};
      for (var person in data.participants) {
        double personTotal = 0.0;

        // Sum all item assignments for this person
        for (var billItem in data.items) {
          personTotal += billItem.amountForPerson(person);
        }

        newPersonTotals[person] = personTotal;
      }

      // Calculate unassigned amount
      double assignedTotal = newPersonTotals.values.fold(
        0,
        (sum, amount) => sum + amount,
      );
      double unassignedAmount = data.subtotal - assignedTotal;

      // Calculate final shares based on updated person totals
      final personFinalShares = calculateFinalShares(
        data.copyWith(
          personTotals: newPersonTotals,
          unassignedAmount: unassignedAmount,
        ),
      );

      // Return updated assignment data
      return data.copyWith(
        personTotals: newPersonTotals,
        personFinalShares: personFinalShares,
        unassignedAmount: unassignedAmount,
      );
    }

    return data;
  }

  /// Split unassigned amount evenly among participants
  static AssignmentData splitUnassignedAmountEvenly(AssignmentData data) {
    if (data.unassignedAmount <= 0) return data;

    // Count paying participants (exclude birthday person)
    int payingPeople = data.participants.length;
    if (data.birthdayPerson != null) payingPeople--;

    if (payingPeople <= 0) return data;

    // Calculate even share of unassigned amount
    double evenShare = data.unassignedAmount / payingPeople;

    // Add to each person's total
    Map<Person, double> newPersonTotals = Map.from(data.personTotals);
    for (var person in data.participants) {
      if (person != data.birthdayPerson) {
        newPersonTotals[person] =
            (newPersonTotals[person] ?? 0.0) + evenShare;
      }
    }

    // If no items, create dummy assignments in personTotals
    if (data.items.isEmpty) {
      // Calculate final shares based on updated person totals
      final personFinalShares = calculateFinalShares(
        data.copyWith(
          personTotals: newPersonTotals,
          unassignedAmount: 0.0,
        ),
      );

      // Return updated assignment data
      return data.copyWith(
        personTotals: newPersonTotals,
        personFinalShares: personFinalShares,
        unassignedAmount: 0.0,
      );
    } else {
      // If there are items but some amount is unassigned,
      // we need to assign that amount evenly to all existing items

      // Calculate what percentage of each item is currently unassigned
      double totalUnassignedPercentage = 0;
      for (var item in data.items) {
        double assignedPercentage = item.assignments.values.fold(
          0.0,
          (sum, value) => sum + value,
        );
        totalUnassignedPercentage += (100.0 - assignedPercentage);
      }

      // For each item, assign its unassigned portion evenly
      for (var item in data.items) {
        // Get current assigned percentage
        double currentAssignedPercentage = item.assignments.values.fold(
          0.0,
          (sum, value) => sum + value,
        );

        // Skip if item is already fully assigned
        if (currentAssignedPercentage >= 100.0) continue;

        // Calculate unassigned percentage for this item
        double itemUnassignedPercentage = 100.0 - currentAssignedPercentage;

        // Create a copy of current assignments
        Map<Person, double> newAssignments = Map.from(item.assignments);

        // For each paying person, add their share of the unassigned percentage
        for (var person in data.participants) {
          if (person != data.birthdayPerson) {
            // Calculate this person's share of the unassigned percentage
            double personShareOfUnassigned =
                itemUnassignedPercentage / payingPeople;

            // Add to their current assignment (or set if not already assigned)
            newAssignments[person] =
                (newAssignments[person] ?? 0.0) + personShareOfUnassigned;
          }
        }

        // Update the item's assignments
        item.assignments = newAssignments;
      }

      // Recalculate person totals based on the updated item assignments
      newPersonTotals = {};
      for (var person in data.participants) {
        double personTotal = 0.0;

        // Sum all item assignments for this person
        for (var billItem in data.items) {
          personTotal += billItem.amountForPerson(person);
        }

        newPersonTotals[person] = personTotal;
      }

      // Calculate final shares based on updated person totals
      final personFinalShares = calculateFinalShares(
        data.copyWith(
          personTotals: newPersonTotals,
          unassignedAmount: 0.0,
        ),
      );

      // Return updated assignment data
      return data.copyWith(
        personTotals: newPersonTotals,
        personFinalShares: personFinalShares,
        unassignedAmount: 0.0,
      );
    }
  }
}