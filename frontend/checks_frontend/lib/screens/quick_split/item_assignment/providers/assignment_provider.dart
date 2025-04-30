import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/assignment_data.dart';
import '../utils/assignment_utils.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

class AssignmentProvider extends ChangeNotifier {
  AssignmentData _data;

  // Universal food/drink icon
  final IconData universalItemIcon = Icons.restaurant_menu;

  AssignmentProvider({
    required List<Person> participants,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required double total,
    required double tipPercentage,
    required double alcoholTipPercentage,
    required bool useDifferentAlcoholTip,
    required bool isCustomTipAmount,
  }) : _data = AssignmentData.initial(
         participants: participants,
         items: items,
         subtotal: subtotal,
         tax: tax,
         tipAmount: tipAmount,
         total: total,
         tipPercentage: tipPercentage,
         alcoholTipPercentage: alcoholTipPercentage,
         useDifferentAlcoholTip: useDifferentAlcoholTip,
         isCustomTipAmount: isCustomTipAmount,
       ) {
    // Initialize data with calculated values
    _calculateInitialAssignments();
  }

  // Getters for the data
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

  // Initialize with calculated values
  void _calculateInitialAssignments() {
    _data = AssignmentUtils.calculateInitialAssignments(_data);
    notifyListeners();
  }

  // Handle person selection
  void togglePersonSelection(Person person) {
    if (_data.selectedPerson == person) {
      _data = _data.copyWith(clearSelectedPerson: true);
    } else {
      _data = _data.copyWith(selectedPerson: person);
      HapticFeedback.selectionClick();
    }
    notifyListeners();
  }

  // Toggle birthday person
  void toggleBirthdayPerson(Person person) {
    if (_data.birthdayPerson == person) {
      _data = _data.copyWith(clearBirthdayPerson: true);
      HapticFeedback.mediumImpact();
    } else {
      _data = _data.copyWith(birthdayPerson: person);

      // If the selected person is now the birthday person, deselect them
      if (_data.selectedPerson == person) {
        _data = _data.copyWith(clearSelectedPerson: true);
      }

      // Important: Unassign all items from the birthday person
      _data = AssignmentUtils.unassignItemsFromBirthdayPerson(_data, person);

      HapticFeedback.mediumImpact();
    }

    // Important: If no items, recalculate initial assignments to handle birthday person
    if (_data.items.isEmpty) {
      _data = AssignmentUtils.calculateInitialAssignments(_data);
    }

    notifyListeners();
  }

  // Assign an item to participants
  void assignItem(BillItem item, Map<Person, double> newAssignments) {
    HapticFeedback.mediumImpact(); // Provide haptic feedback
    _data = AssignmentUtils.assignItem(_data, item, newAssignments);
    notifyListeners();
  }

  // Evenly split an item among selected participants
  void splitItemEvenly(BillItem item, List<Person> people) {
    if (people.isEmpty) return;

    Map<Person, double> newAssignments = AssignmentUtils.splitItemEvenly(
      people,
    );
    assignItem(item, newAssignments);
  }

  // Balance an item between current assignees
  void balanceItemBetweenAssignees(BillItem item, List<Person> assignedPeople) {
    if (assignedPeople.isEmpty) return;

    Map<Person, double> newAssignments =
        AssignmentUtils.balanceItemBetweenAssignees(item, assignedPeople);
    assignItem(item, newAssignments);
  }

  // Split unassigned amount evenly among participants
  void splitUnassignedAmountEvenly() {
    if (_data.unassignedAmount <= 0) return;

    _data = AssignmentUtils.splitUnassignedAmountEvenly(_data);

    // Add a success sound or animation here
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  // Helper method to get a person's percentage of the total bill
  double getPersonBillPercentage(Person person) {
    return AssignmentUtils.getPersonBillPercentage(person, _data);
  }
}
