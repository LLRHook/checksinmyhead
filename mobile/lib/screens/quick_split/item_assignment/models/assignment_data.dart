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

/// AssignmentData
///
/// This class serves as a centralized container for all data related to bill splitting
/// and item assignments. It holds information about participants, bill items,
/// monetary values (subtotal, tax, tip, etc.), and the current state of assignments.
///
/// The class is immutable - all updates are made through the copyWith method, which
/// creates a new instance with the specified changes. This pattern supports a clean,
/// predictable state management approach.
class AssignmentData {
  // Bill participants and items
  final List<Person> participants; // People sharing the bill
  final List<BillItem> items; // Individual items on the bill

  // Bill monetary values
  final double subtotal; // Sum of all item prices
  final double tax; // Tax amount
  final double tipAmount; // Tip amount in currency
  final double total; // Total bill amount (subtotal + tax + tip)
  final double tipPercentage; // Tip as percentage of subtotal
  final bool
  isCustomTipAmount; // Whether tip was entered as amount (true) or percentage (false)

  // Assignment state data
  final Map<Person, double>
  personTotals; // Amount assigned to each person (item costs only)
  final Map<Person, double>
  personFinalShares; // Final amounts including tax and tip
  final double unassignedAmount; // Portion of bill not yet assigned to anyone
  final Person? selectedPerson; // Currently selected person in the UI
  final Person?
  birthdayPerson; // Person receiving special handling (e.g., birthday discount)

  /// Creates an instance of AssignmentData with all required fields.
  ///
  /// All fields are final since this is an immutable data class.
  /// Updates should be made through the copyWith method.
  const AssignmentData({
    required this.participants,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    required this.tipPercentage,
    required this.isCustomTipAmount,
    required this.personTotals,
    required this.personFinalShares,
    required this.unassignedAmount,
    this.selectedPerson,
    this.birthdayPerson,
  });

  /// Creates a new AssignmentData instance with updated values.
  ///
  /// This method implements the immutable update pattern, allowing selective
  /// updating of properties while preserving the values of properties that
  /// aren't explicitly changed.
  ///
  /// @param participants Updated list of participants
  /// @param items Updated list of bill items
  /// @param subtotal Updated subtotal amount
  /// @param tax Updated tax amount
  /// @param tipAmount Updated tip amount
  /// @param total Updated total bill amount
  /// @param tipPercentage Updated tip percentage
  /// @param alcoholTipPercentage Legacy parameter (not used in current implementation)
  /// @param useDifferentAlcoholTip Legacy parameter (not used in current implementation)
  /// @param isCustomTipAmount Whether tip is specified as amount or percentage
  /// @param personTotals Updated amounts assigned to each person
  /// @param personFinalShares Updated final shares including tax and tip
  /// @param unassignedAmount Updated unassigned amount
  /// @param selectedPerson Updated selected person
  /// @param clearSelectedPerson When true, clears selected person regardless of selectedPerson param
  /// @param birthdayPerson Updated birthday person
  /// @param clearBirthdayPerson When true, clears birthday person regardless of birthdayPerson param
  ///
  /// @return A new AssignmentData instance with updated values
  AssignmentData copyWith({
    List<Person>? participants,
    List<BillItem>? items,
    double? subtotal,
    double? tax,
    double? tipAmount,
    double? total,
    double? tipPercentage,
    double? alcoholTipPercentage, // Legacy parameter
    bool? useDifferentAlcoholTip, // Legacy parameter
    bool? isCustomTipAmount,
    Map<Person, double>? personTotals,
    Map<Person, double>? personFinalShares,
    double? unassignedAmount,
    Person? selectedPerson,
    bool clearSelectedPerson = false,
    Person? birthdayPerson,
    bool clearBirthdayPerson = false,
  }) {
    return AssignmentData(
      participants: participants ?? this.participants,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      tipAmount: tipAmount ?? this.tipAmount,
      total: total ?? this.total,
      tipPercentage: tipPercentage ?? this.tipPercentage,
      isCustomTipAmount: isCustomTipAmount ?? this.isCustomTipAmount,
      personTotals: personTotals ?? this.personTotals,
      personFinalShares: personFinalShares ?? this.personFinalShares,
      unassignedAmount: unassignedAmount ?? this.unassignedAmount,
      selectedPerson:
          clearSelectedPerson ? null : (selectedPerson ?? this.selectedPerson),
      birthdayPerson:
          clearBirthdayPerson ? null : (birthdayPerson ?? this.birthdayPerson),
    );
  }

  /// Factory method that creates an initial instance with empty state data.
  ///
  /// This is typically used when starting a new bill split, before any items
  /// have been assigned to participants.
  ///
  /// @param participants List of people participating in the bill
  /// @param items List of bill items to be split
  /// @param subtotal Sum of all item prices
  /// @param tax Tax amount
  /// @param tipAmount Tip amount
  /// @param total Total bill amount
  /// @param tipPercentage Tip as percentage of subtotal
  /// @param isCustomTipAmount Whether tip was entered as amount or percentage
  ///
  /// @return A new AssignmentData instance with empty/initial state values
  factory AssignmentData.initial({
    required List<Person> participants,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    required double tipPercentage,
    required bool isCustomTipAmount,
  }) {
    return AssignmentData(
      participants: participants,
      items: items,
      subtotal: subtotal,
      tax: tax,
      tipAmount: tipAmount,
      total: total,
      tipPercentage: tipPercentage,
      isCustomTipAmount: isCustomTipAmount,
      personTotals: {}, // Initially empty - no assignments
      personFinalShares: {}, // Initially empty - no calculated shares
      unassignedAmount:
          items.isEmpty ? 0.0 : subtotal, // All items unassigned initially
      selectedPerson: null, // No person selected initially
      birthdayPerson: null, // No birthday person initially
    );
  }
}
