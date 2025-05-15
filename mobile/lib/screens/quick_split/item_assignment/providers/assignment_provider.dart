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

import 'package:checks_frontend/screens/quick_split/item_assignment/models/assignment_data.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/assignment_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

/// AssignmentProvider
///
/// A ChangeNotifier that manages the state of bill splitting assignments.
/// This provider serves as the central state management class for the bill
/// splitting functionality, handling all operations that modify the assignment state
/// such as selecting participants, assigning items, and calculating shares.
///
/// It uses the AssignmentData immutable data class to store the current state
/// and AssignmentUtils to perform calculations.
///
/// This provider properly cleans up resources when disposed to prevent memory leaks.
class AssignmentProvider extends ChangeNotifier {
  late AssignmentData _data;

  // Icons used for categorizing bill items
  final IconData universalItemIcon =
      Icons.restaurant_menu; // For general food/drink items
  final IconData alcoholItemIcon = Icons.local_bar; // For alcohol items

  /// Creates an AssignmentProvider with initial bill data.
  ///
  /// @param participants List of people participating in the bill
  /// @param items List of bill items to be split
  /// @param subtotal Sum of all item prices before tax and tip
  /// @param tax Tax amount
  /// @param tipAmount Tip amount in currency
  /// @param total Total bill amount (subtotal + tax + tip)
  /// @param tipPercentage Tip as percentage of subtotal
  /// @param isCustomTipAmount Whether tip was entered as amount (true) or percentage (false)
  /// @param initialBirthdayPerson The initial birthday person for the bill
  AssignmentProvider({
    required List<Person> participants,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    required double tipPercentage,
    required bool isCustomTipAmount,
    Person? initialBirthdayPerson,
  }) {
    // Initialize data with provided values
    _data = AssignmentData.initial(
      participants: participants,
      items: items,
      subtotal: subtotal,
      tax: tax,
      tipAmount: tipAmount,
      total: total,
      tipPercentage: tipPercentage,
      isCustomTipAmount: isCustomTipAmount,
      birthdayPerson: initialBirthdayPerson,
    );

    // Check if items already have assignments
    bool hasExistingAssignments = false;
    for (var item in items) {
      if (item.assignments.isNotEmpty) {
        hasExistingAssignments = true;
        break;
      }
    }

    if (hasExistingAssignments) {
      // Use the existing assignments instead of initializing from scratch
      _recalculateFromExistingAssignments();
    } else {
      // Initialize data with calculated values including tax and tip distribution
      _calculateInitialAssignments();
    }
  }

  // Getters for accessing the data properties
  AssignmentData get data => _data;
  List<Person> get participants => _data.participants;
  List<BillItem> get items => _data.items;
  double get subtotal => _data.subtotal;
  double get tax => _data.tax;
  double get tipAmount => _data.tipAmount;
  double get total => _data.total;
  double get tipPercentage => _data.tipPercentage;
  bool get isCustomTipAmount => _data.isCustomTipAmount;
  Map<Person, double> get personTotals => _data.personTotals;
  Map<Person, double> get personFinalShares => _data.personFinalShares;
  double get unassignedAmount => _data.unassignedAmount;
  Person? get selectedPerson => _data.selectedPerson;
  Person? get birthdayPerson => _data.birthdayPerson;

  /// Initializes assignments and calculates each person's share
  /// including proportional tax and tip allocation.
  ///
  /// This is called during initialization and when significant
  /// changes to the assignment state occur.
  void _calculateInitialAssignments() {
    _data = AssignmentUtils.calculateInitialAssignments(_data);
    notifyListeners();
  }

  /// Recalculates assignment data based on existing item assignments
  void _recalculateFromExistingAssignments() {
    // Calculate person totals from existing assignments
    Map<Person, double> personItemTotals = {};

    for (var person in _data.participants) {
      double total = 0.0;

      for (var item in _data.items) {
        if (item.assignments.containsKey(person)) {
          total += item.price * item.assignments[person]! / 100.0;
        }
      }

      personItemTotals[person] = total;
    }

    // Calculate unassigned amount
    double assignedAmount = personItemTotals.values.fold(
      0.0,
      (sum, amount) => sum + amount,
    );
    double unassignedAmount = _data.subtotal - assignedAmount;

    // Calculate tax and tip distribution proportionally
    Map<Person, double> personTaxAndTip = {};
    Map<Person, double> personFinalShares = {};

    double totalTaxAndTip = _data.tax + _data.tipAmount;

    for (var entry in personItemTotals.entries) {
      if (assignedAmount > 0) {
        // Calculate proportional tax and tip
        double proportion = entry.value / assignedAmount;
        double taxAndTipShare = totalTaxAndTip * proportion;
        personTaxAndTip[entry.key] = taxAndTipShare;

        // Final share includes items plus tax and tip
        personFinalShares[entry.key] = entry.value + taxAndTipShare;
      } else {
        personTaxAndTip[entry.key] = 0.0;
        personFinalShares[entry.key] = 0.0;
      }
    }

    // Update the data with calculated values
    _data = _data.copyWith(
      personTotals: personItemTotals,
      personFinalShares: personFinalShares,
      unassignedAmount: unassignedAmount,
    );

    notifyListeners();
  }

  /// Toggles selection state for a person.
  ///
  /// If the person is already selected, they will be deselected.
  /// Otherwise, they will be selected and any previously selected
  /// person will be deselected.
  ///
  /// @param person The person to toggle selection for
  void togglePersonSelection(Person person) {
    if (_data.selectedPerson == person) {
      _data = _data.copyWith(clearSelectedPerson: true);
    } else {
      _data = _data.copyWith(selectedPerson: person);
      HapticFeedback.selectionClick();
    }
    notifyListeners();
  }

  /// Toggles birthday status for a person.
  ///
  /// Birthday persons receive special handling, such as having their
  /// items paid for by others. If the person already has birthday status,
  /// it will be removed. Otherwise, they will be marked as the birthday person
  /// and any previous birthday person designation will be cleared.
  ///
  /// @param person The person to toggle birthday status for
  void toggleBirthdayPerson(Person person) {
    if (_data.birthdayPerson == person) {
      _data = _data.copyWith(clearBirthdayPerson: true);
      HapticFeedback.mediumImpact();
    } else {
      _data = _data.copyWith(birthdayPerson: person);

      // If the selected person is now the birthday person, deselect them
      // to avoid confusion in the UI
      if (_data.selectedPerson == person) {
        _data = _data.copyWith(clearSelectedPerson: true);
      }

      // Remove any existing item assignments from the birthday person
      // since their items will be covered by others
      _data = AssignmentUtils.unassignItemsFromBirthdayPerson(_data, person);

      HapticFeedback.mediumImpact();
    }

    // Recalculate assignments if needed (e.g., with no items)
    // to properly handle birthday person's share
    if (_data.items.isEmpty) {
      _data = AssignmentUtils.calculateInitialAssignments(_data);
    }

    notifyListeners();
  }

  /// Assigns an item to participants based on the given percentage distribution.
  ///
  /// @param item The bill item to assign
  /// @param newAssignments Map of Person to percentage values (0-100)
  void assignItem(BillItem item, Map<Person, double> newAssignments) {
    HapticFeedback.mediumImpact(); // Provide haptic feedback for user confirmation
    _data = AssignmentUtils.assignItem(_data, item, newAssignments);
    notifyListeners();
  }

  /// Splits an item evenly among the specified participants.
  ///
  /// @param item The bill item to split
  /// @param people List of people to split the item among
  void splitItemEvenly(BillItem item, List<Person> people) {
    if (people.isEmpty) return;

    // Calculate even split percentages
    Map<Person, double> newAssignments = AssignmentUtils.splitItemEvenly(
      people,
    );
    assignItem(item, newAssignments);
  }

  /// Rebalances an item equally between people who already have a share of it.
  ///
  /// This is useful for redistributing percentages when people are added
  /// or removed from an item's assignment.
  ///
  /// @param item The bill item to rebalance
  /// @param assignedPeople List of people currently assigned to the item
  void balanceItemBetweenAssignees(BillItem item, List<Person> assignedPeople) {
    if (assignedPeople.isEmpty) return;

    Map<Person, double> newAssignments =
        AssignmentUtils.balanceItemBetweenAssignees(item, assignedPeople);
    assignItem(item, newAssignments);
  }

  /// Splits any remaining unassigned amount evenly among all participants.
  ///
  /// This is typically used at the end of the bill splitting process to
  /// distribute any items that haven't been manually assigned.
  void splitUnassignedAmountEvenly() {
    if (_data.unassignedAmount <= 0) return;

    _data = AssignmentUtils.splitUnassignedAmountEvenly(_data);

    // Provide tactile feedback to confirm the action
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Calculates a person's percentage of the total bill.
  /// This is useful for UI displays showing proportional contributions.
  /// @param person The person to calculate percentage for
  /// @return The percentage of the total bill assigned to the person
  double getPersonBillPercentage(Person person) {
    return AssignmentUtils.getPersonBillPercentage(person, _data);
  }

  /// Cleanup resources when the provider is no longer needed
  /// to prevent memory leaks.
  @override
  void dispose() {
    // Clear any references that might cause memory leaks
    _data = _data.copyWith(
      clearSelectedPerson: true,
      clearBirthdayPerson: true,
    );

    // Call the parent dispose method
    super.dispose();
  }
}
