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

import 'package:checks_frontend/screens/quick_split/item_assignment/models/assignment_data.dart';
import 'package:flutter/material.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

/// A utility class that handles the logic for bill splitting and item assignment
/// in a group payment scenario.
///
/// This class provides methods for:
/// - Managing item assignments between people
/// - Calculating individual payment shares
/// - Handling special cases like birthday person exemptions
/// - Visualizing assignment status through colors
/// - Redistributing unassigned amounts
///
/// The class operates on the [AssignmentData] model which contains
/// bill information, participants, and item assignments.
class AssignmentUtils {
  /// Determines the background color for an item based on its assignment status.
  ///
  /// Returns:
  /// - The person's color (with reduced opacity) if the item is fully assigned to one person
  /// - The default color if the item is either unassigned or split between multiple people
  ///
  /// Parameters:
  /// - [item]: The bill item to evaluate
  /// - [defaultColor]: The fallback color to use for partially assigned items
  static Color getAssignmentColor(BillItem item, Color defaultColor) {
    // If fully assigned to one person (100%), use their color with transparency
    if (item.assignments.length == 1 &&
        item.assignments.values.first == 100.0) {
      return item.assignments.keys.first.color.withValues(alpha: .2);
    }
    // For partially assigned or unassigned items, use the default color
    return defaultColor;
  }

  /// Checks if a specific person is assigned to a bill item.
  ///
  /// A person is considered assigned if their percentage is greater than zero.
  ///
  /// Parameters:
  /// - [item]: The bill item to check
  /// - [person]: The person to check for assignment
  ///
  /// Returns true if the person is assigned to the item, false otherwise.
  static bool isPersonAssignedToItem(BillItem item, Person person) {
    return item.assignments.containsKey(person) &&
        item.assignments[person]! > 0;
  }

  /// Retrieves a list of all people assigned to a specific bill item.
  ///
  /// Only includes people with assignment percentages greater than zero.
  ///
  /// Parameters:
  /// - [item]: The bill item to check
  ///
  /// Returns a list of Person objects assigned to the item.
  static List<Person> getAssignedPeopleForItem(BillItem item) {
    return item.assignments.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
  }

  /// Redistributes an item's cost evenly among the currently assigned people.
  ///
  /// This rebalances the percentages so each assigned person pays an equal share.
  ///
  /// Parameters:
  /// - [item]: The bill item to balance
  /// - [assignedPeople]: List of people currently assigned to the item
  ///
  /// Returns a new assignment map with balanced percentages.
  /// Returns an empty map if no people are assigned.
  static Map<Person, double> balanceItemBetweenAssignees(
    BillItem item,
    List<Person> assignedPeople,
  ) {
    if (assignedPeople.isEmpty) return {};

    Map<Person, double> newAssignments = {};
    // Calculate equal percentage for each person (total must equal 100%)
    double percentage = 100.0 / assignedPeople.length;

    for (var person in assignedPeople) {
      newAssignments[person] = percentage;
    }

    return newAssignments;
  }

  /// Calculates what percentage of the total bill a person is responsible for.
  ///
  /// This is based on their final share (including tax and tip) divided by the total.
  ///
  /// Parameters:
  /// - [person]: The person to calculate for
  /// - [data]: The current assignment data
  ///
  /// Returns a value between 0.0 and 1.0 representing the person's percentage of the bill.
  static double getPersonBillPercentage(Person person, AssignmentData data) {
    // Avoid division by zero by using 1.0 as minimum denominator
    final total = data.total > 0 ? data.total : 1.0;
    final share = data.personFinalShares[person] ?? 0.0;
    return (share / total).clamp(0.0, 1.0);
  }

  /// Sets up initial assignments when a bill is first created.
  ///
  /// Handles two main scenarios:
  /// 1. No items entered: Splits subtotal evenly among participants (except birthday person)
  /// 2. Items entered but not assigned: Sets all amount as unassigned
  ///
  /// Parameters:
  /// - [data]: The current assignment data
  ///
  /// Returns updated assignment data with initial values calculated.
  static AssignmentData calculateInitialAssignments(AssignmentData data) {
    Map<Person, double> personTotals = {};
    double unassignedAmount = 0.0;

    if (data.items.isEmpty) {
      // No items scenario: split subtotal evenly
      // Exclude birthday person from calculations if present
      int payingPeople = data.participants.length;
      if (data.birthdayPerson != null) payingPeople--;

      // Calculate even share, avoiding division by zero
      double evenShare = payingPeople > 0 ? data.subtotal / payingPeople : 0.0;

      for (var person in data.participants) {
        if (data.birthdayPerson == person) {
          personTotals[person] = 0.0; // Birthday person pays nothing
        } else {
          personTotals[person] = evenShare; // Everyone else pays equal share
        }
      }

      unassignedAmount = 0.0; // All amount is assigned in this scenario
    } else {
      // Items entered but not assigned: all amount is unassigned
      unassignedAmount = data.subtotal;

      // Initialize all person totals to zero
      for (var person in data.participants) {
        personTotals[person] = 0.0;
      }
    }

    // Calculate final shares including tax and tip
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

  /// Calculates each person's final payment amount including their share of tax and tip.
  ///
  /// The calculation handles special cases:
  /// - Birthday person exempt from payment
  /// - Tax and tip distributed proportionally to item assignments
  /// - Even split if nothing is assigned yet
  ///
  /// Parameters:
  /// - [data]: The current assignment data
  ///
  /// Returns a map of Person to their final payment amount.
  static Map<Person, double> calculateFinalShares(AssignmentData data) {
    Map<Person, double> newShares = {};

    // Calculate total assigned amount to determine proportions
    double totalAssigned = data.personTotals.values.fold(
      0,
      (sum, amount) => sum + amount,
    );

    // If any amount has been assigned, distribute tax and tip proportionally
    if (totalAssigned > 0) {
      for (var person in data.participants) {
        if (data.birthdayPerson == person) {
          // Birthday person special case: pays nothing
          newShares[person] = 0.0;
          continue;
        }

        double personSubtotal = data.personTotals[person] ?? 0.0;
        // Calculate person's percentage of the assigned total
        double personPercentage = personSubtotal / totalAssigned;

        // Calculate person's proportional share of tax and tip
        double personTax = data.tax * personPercentage;
        double personTip = data.tipAmount * personPercentage;

        // Final share = subtotal + tax + tip
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
            newShares[person] = 0.0; // Birthday person pays nothing
          } else {
            newShares[person] = evenShare; // Equal share for everyone else
          }
        }
      }
    }

    return newShares;
  }

  /// Updates a bill item's assignments and recalculates all dependent values.
  ///
  /// This is the primary method for changing item assignments. It:
  /// 1. Updates the item's assignment percentages
  /// 2. Recalculates each person's total based on all items
  /// 3. Determines the amount left unassigned
  /// 4. Calculates final payment shares including tax and tip
  ///
  /// Parameters:
  /// - [data]: The current assignment data
  /// - [item]: The bill item being assigned
  /// - [newAssignments]: Map of Person to their percentage of this item
  ///
  /// Returns updated assignment data reflecting the new assignments.
  static AssignmentData assignItem(
    AssignmentData data,
    BillItem item,
    Map<Person, double> newAssignments,
  ) {
    // Update item assignments with new percentages
    item.assignments = newAssignments;

    // Recalculate person totals based on all item assignments
    Map<Person, double> newPersonTotals = {};
    for (var person in data.participants) {
      double personTotal = 0.0;

      // Sum all item assignments for this person
      for (var billItem in data.items) {
        personTotal += billItem.amountForPerson(person);
      }

      newPersonTotals[person] = personTotal;
    }

    // Calculate how much of the bill remains unassigned
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

  /// Creates a map of assignments to evenly split an item among specified people.
  ///
  /// Each person receives an equal percentage of the item, totaling 100%.
  ///
  /// Parameters:
  /// - [people]: List of people to split the item among
  ///
  /// Returns a map of Person to their percentage assignment.
  /// Returns an empty map if the people list is empty.
  static Map<Person, double> splitItemEvenly(List<Person> people) {
    if (people.isEmpty) return {};

    Map<Person, double> newAssignments = {};
    double percentage = 100.0 / people.length;

    for (var person in people) {
      newAssignments[person] = percentage;
    }

    return newAssignments;
  }

  /// Removes a birthday person from all item assignments and redistributes their share.
  ///
  /// When a person is marked as the birthday person, this method:
  /// 1. Removes them from all item assignments
  /// 2. Proportionally redistributes their share among other assignees
  /// 3. Recalculates all dependent values
  ///
  /// Parameters:
  /// - [data]: The current assignment data
  /// - [birthdayPerson]: The person being designated as the birthday person
  ///
  /// Returns updated assignment data with the birthday person removed from assignments.
  static AssignmentData unassignItemsFromBirthdayPerson(
    AssignmentData data,
    Person birthdayPerson,
  ) {
    // Track whether any changes were made to avoid unnecessary recalculations
    bool changesDetected = false;

    // Process each item to remove birthday person's assignments
    for (var item in data.items) {
      if (item.assignments.containsKey(birthdayPerson)) {
        // Get the percentage that was assigned to birthday person
        double birthdayPersonPercentage =
            item.assignments[birthdayPerson] ?? 0.0;

        if (birthdayPersonPercentage > 0) {
          changesDetected = true;

          // Create a new assignment map without the birthday person
          Map<Person, double> newAssignments = Map.from(item.assignments);
          newAssignments.remove(birthdayPerson);

          // If other people are assigned to this item, redistribute the birthday person's share
          if (newAssignments.isNotEmpty) {
            // Calculate total percentage among remaining assignees
            double totalRemaining = newAssignments.values.fold(
              0.0,
              (sum, value) => sum + value,
            );

            if (totalRemaining > 0) {
              // Calculate scaling factor to ensure percentages total 100%
              // Example: If remaining was 60% and we need 100%, scale by 100/60 = 1.67
              double scaleFactor = 100.0 / totalRemaining;

              // Rescale everyone else's percentages proportionally
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

    // Only recalculate if changes were made
    if (changesDetected) {
      // Recalculate person totals based on updated assignments
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

    // Return unchanged data if no modifications were made
    return data;
  }

  /// Distributes any unassigned amount evenly among all paying participants.
  ///
  /// This method handles two scenarios:
  /// 1. No items: Creates dummy assignments to split the amount
  /// 2. With items: Distributes unassigned portions of items evenly
  ///
  /// The birthday person (if any) is excluded from this distribution.
  ///
  /// Parameters:
  /// - [data]: The current assignment data
  ///
  /// Returns updated assignment data with unassigned amount distributed.
  static AssignmentData splitUnassignedAmountEvenly(AssignmentData data) {
    // Skip if there's nothing to distribute
    if (data.unassignedAmount <= 0) return data;

    // Count participants who should pay (exclude birthday person)
    int payingPeople = data.participants.length;
    if (data.birthdayPerson != null) payingPeople--;

    // Skip if there's no one to pay
    if (payingPeople <= 0) return data;

    // Calculate even share of unassigned amount
    double evenShare = data.unassignedAmount / payingPeople;

    // Create new person totals based on current values
    Map<Person, double> newPersonTotals = Map.from(data.personTotals);

    // Add even share to each person (except birthday person)
    for (var person in data.participants) {
      if (person != data.birthdayPerson) {
        newPersonTotals[person] = (newPersonTotals[person] ?? 0.0) + evenShare;
      }
    }

    // Handle case where there are no items (create dummy assignments)
    if (data.items.isEmpty) {
      // Calculate final shares based on updated person totals
      final personFinalShares = calculateFinalShares(
        data.copyWith(personTotals: newPersonTotals, unassignedAmount: 0.0),
      );

      // Return updated assignment data with unassigned amount now distributed
      return data.copyWith(
        personTotals: newPersonTotals,
        personFinalShares: personFinalShares,
        unassignedAmount: 0.0,
      );
    } else {
      // Handle case with items - distribute unassigned portions of each item

      // For each item, assign its unassigned portion evenly
      for (var item in data.items) {
        // Calculate current assigned percentage for this item
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

        // Distribute unassigned percentage evenly among paying participants
        for (var person in data.participants) {
          if (person != data.birthdayPerson) {
            // Calculate person's equal share of the unassigned percentage
            double personShareOfUnassigned =
                itemUnassignedPercentage / payingPeople;

            // Add to their current assignment (or create if not already assigned)
            newAssignments[person] =
                (newAssignments[person] ?? 0.0) + personShareOfUnassigned;
          }
        }

        // Update the item's assignments
        item.assignments = newAssignments;
      }

      // Recalculate person totals based on updated item assignments
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
        data.copyWith(personTotals: newPersonTotals, unassignedAmount: 0.0),
      );

      // Return updated assignment data with unassigned amount now distributed
      return data.copyWith(
        personTotals: newPersonTotals,
        personFinalShares: personFinalShares,
        unassignedAmount: 0.0,
      );
    }
  }
}
