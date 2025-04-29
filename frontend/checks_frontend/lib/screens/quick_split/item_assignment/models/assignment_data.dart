import '/models/person.dart';
import '/models/bill_item.dart';

/// A class to hold all the item assignment data
class AssignmentData {
  final List<Person> participants;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double total;
  final double tipPercentage;
  final double alcoholTipPercentage;
  final bool useDifferentAlcoholTip;
  final bool isCustomTipAmount;

  // State data
  final Map<Person, double> personTotals;
  final Map<Person, double> personFinalShares;
  final double unassignedAmount;
  final Person? selectedPerson;
  final Person? birthdayPerson;

  const AssignmentData({
    required this.participants,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    required this.total,
    required this.tipPercentage,
    required this.alcoholTipPercentage,
    required this.useDifferentAlcoholTip,
    required this.isCustomTipAmount,
    required this.personTotals,
    required this.personFinalShares,
    required this.unassignedAmount,
    this.selectedPerson,
    this.birthdayPerson,
  });

  /// Create a copy of the assignment data with updated values
  AssignmentData copyWith({
    List<Person>? participants,
    List<BillItem>? items,
    double? subtotal,
    double? tax,
    double? tipAmount,
    double? total,
    double? tipPercentage,
    double? alcoholTipPercentage,
    bool? useDifferentAlcoholTip,
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
      alcoholTipPercentage: alcoholTipPercentage ?? this.alcoholTipPercentage,
      useDifferentAlcoholTip: useDifferentAlcoholTip ?? this.useDifferentAlcoholTip,
      isCustomTipAmount: isCustomTipAmount ?? this.isCustomTipAmount,
      personTotals: personTotals ?? this.personTotals,
      personFinalShares: personFinalShares ?? this.personFinalShares,
      unassignedAmount: unassignedAmount ?? this.unassignedAmount,
      selectedPerson: clearSelectedPerson ? null : (selectedPerson ?? this.selectedPerson),
      birthdayPerson: clearBirthdayPerson ? null : (birthdayPerson ?? this.birthdayPerson),
    );
  }

  /// Factory method to create an initial instance with empty state data
  factory AssignmentData.initial({
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
  }) {
    return AssignmentData(
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
      personTotals: {},
      personFinalShares: {},
      unassignedAmount: items.isEmpty ? 0.0 : subtotal,
      selectedPerson: null,
      birthdayPerson: null,
    );
  }
}