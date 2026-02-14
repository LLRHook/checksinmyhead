import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/models/assignment_data.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/assignment_utils.dart';

void main() {
  final alice = Person(name: 'Alice', color: Colors.blue);
  final bob = Person(name: 'Bob', color: Colors.red);
  final charlie = Person(name: 'Charlie', color: Colors.green);

  AssignmentData makeData({
    List<Person>? participants,
    List<BillItem>? items,
    double subtotal = 100.0,
    double tax = 10.0,
    double tipAmount = 15.0,
    double total = 125.0,
    Map<Person, double>? personTotals,
    Map<Person, double>? personFinalShares,
    double unassignedAmount = 0.0,
    Person? birthdayPerson,
  }) {
    return AssignmentData(
      participants: participants ?? [alice, bob],
      items: items ?? [],
      subtotal: subtotal,
      tax: tax,
      tipAmount: tipAmount,
      total: total,
      tipPercentage: 15.0,
      isCustomTipAmount: false,
      personTotals: personTotals ?? {},
      personFinalShares: personFinalShares ?? {},
      unassignedAmount: unassignedAmount,
      birthdayPerson: birthdayPerson,
    );
  }

  group('AssignmentUtils.getAssignmentColor', () {
    test('returns person color when fully assigned to one person', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 100.0},
      );
      final color = AssignmentUtils.getAssignmentColor(item, Colors.grey);
      expect(color, equals(alice.color.withValues(alpha: .2)));
    });

    test('returns default color for partially assigned item', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 50.0, bob: 50.0},
      );
      final color = AssignmentUtils.getAssignmentColor(item, Colors.grey);
      expect(color, equals(Colors.grey));
    });

    test('returns default color for unassigned item', () {
      final item = BillItem(name: 'Pizza', price: 20.0, assignments: {});
      final color = AssignmentUtils.getAssignmentColor(item, Colors.grey);
      expect(color, equals(Colors.grey));
    });

    test('returns person color when assignment is near 100% (float tolerance)',
        () {
      // 99.99999 is not exactly 100.0 but should be treated as fully assigned
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 99.999},
      );
      final color = AssignmentUtils.getAssignmentColor(item, Colors.grey);
      expect(color, equals(alice.color.withValues(alpha: .2)));
    });

    test('returns default color when single assignment is far from 100%', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 99.0},
      );
      final color = AssignmentUtils.getAssignmentColor(item, Colors.grey);
      expect(color, equals(Colors.grey));
    });
  });

  group('AssignmentUtils.isPersonAssignedToItem', () {
    test('returns true when person has positive assignment', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 50.0},
      );
      expect(AssignmentUtils.isPersonAssignedToItem(item, alice), isTrue);
    });

    test('returns false when person not in assignments', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 100.0},
      );
      expect(AssignmentUtils.isPersonAssignedToItem(item, bob), isFalse);
    });

    test('returns false when person has 0% assignment', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 0.0},
      );
      expect(AssignmentUtils.isPersonAssignedToItem(item, alice), isFalse);
    });
  });

  group('AssignmentUtils.getAssignedPeopleForItem', () {
    test('returns only people with positive assignments', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 50.0, bob: 0.0},
      );
      final assigned = AssignmentUtils.getAssignedPeopleForItem(item);
      expect(assigned, equals([alice]));
    });

    test('returns empty list for unassigned item', () {
      final item = BillItem(name: 'Pizza', price: 20.0, assignments: {});
      expect(AssignmentUtils.getAssignedPeopleForItem(item), isEmpty);
    });

    test('returns all people when all assigned', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 50.0, bob: 50.0},
      );
      final assigned = AssignmentUtils.getAssignedPeopleForItem(item);
      expect(assigned.length, equals(2));
      expect(assigned, containsAll([alice, bob]));
    });
  });

  group('AssignmentUtils.balanceItemBetweenAssignees', () {
    test('splits evenly between 2 people', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 70.0, bob: 30.0},
      );
      final balanced = AssignmentUtils.balanceItemBetweenAssignees(
        item,
        [alice, bob],
      );
      expect(balanced[alice], equals(50.0));
      expect(balanced[bob], equals(50.0));
    });

    test('splits evenly between 3 people', () {
      final item = BillItem(
        name: 'Pizza',
        price: 30.0,
        assignments: {alice: 100.0},
      );
      final balanced = AssignmentUtils.balanceItemBetweenAssignees(
        item,
        [alice, bob, charlie],
      );
      expect(balanced[alice], closeTo(33.33, 0.01));
      expect(balanced[bob], closeTo(33.33, 0.01));
      expect(balanced[charlie], closeTo(33.33, 0.01));
    });

    test('returns empty map for empty list', () {
      final item = BillItem(name: 'Pizza', price: 20.0, assignments: {});
      final balanced = AssignmentUtils.balanceItemBetweenAssignees(item, []);
      expect(balanced, isEmpty);
    });

    test('assigns 100% to single person', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 100.0},
      );
      final balanced = AssignmentUtils.balanceItemBetweenAssignees(
        item,
        [alice],
      );
      expect(balanced[alice], equals(100.0));
    });
  });

  group('AssignmentUtils.splitItemEvenly', () {
    test('splits 100% between 2 people', () {
      final result = AssignmentUtils.splitItemEvenly([alice, bob]);
      expect(result[alice], equals(50.0));
      expect(result[bob], equals(50.0));
    });

    test('splits 100% between 4 people', () {
      final dana = Person(name: 'Dana', color: Colors.purple);
      final result = AssignmentUtils.splitItemEvenly(
        [alice, bob, charlie, dana],
      );
      expect(result[alice], equals(25.0));
      expect(result[bob], equals(25.0));
      expect(result[charlie], equals(25.0));
      expect(result[dana], equals(25.0));
    });

    test('returns empty map for empty list', () {
      expect(AssignmentUtils.splitItemEvenly([]), isEmpty);
    });

    test('assigns 100% to single person', () {
      final result = AssignmentUtils.splitItemEvenly([alice]);
      expect(result[alice], equals(100.0));
    });
  });

  group('AssignmentUtils.getPersonBillPercentage', () {
    test('returns correct percentage', () {
      final data = makeData(
        total: 100.0,
        personFinalShares: {alice: 60.0, bob: 40.0},
      );
      expect(
        AssignmentUtils.getPersonBillPercentage(alice, data),
        closeTo(0.6, 0.001),
      );
      expect(
        AssignmentUtils.getPersonBillPercentage(bob, data),
        closeTo(0.4, 0.001),
      );
    });

    test('returns 0 for person with no share', () {
      final data = makeData(
        total: 100.0,
        personFinalShares: {alice: 100.0},
      );
      expect(
        AssignmentUtils.getPersonBillPercentage(bob, data),
        equals(0.0),
      );
    });

    test('clamps to 1.0 maximum', () {
      final data = makeData(
        total: 50.0,
        personFinalShares: {alice: 100.0},
      );
      expect(
        AssignmentUtils.getPersonBillPercentage(alice, data),
        equals(1.0),
      );
    });

    test('handles zero total without division error', () {
      final data = makeData(
        total: 0.0,
        personFinalShares: {alice: 0.0},
      );
      expect(
        AssignmentUtils.getPersonBillPercentage(alice, data),
        equals(0.0),
      );
    });
  });

  group('AssignmentUtils.calculateFinalShares', () {
    test('distributes tax and tip proportionally', () {
      final data = makeData(
        participants: [alice, bob],
        subtotal: 100.0,
        tax: 10.0,
        tipAmount: 15.0,
        total: 125.0,
        personTotals: {alice: 60.0, bob: 40.0},
      );

      final shares = AssignmentUtils.calculateFinalShares(data);
      // Alice: 60 + (10 * 0.6) + (15 * 0.6) = 60 + 6 + 9 = 75
      expect(shares[alice], closeTo(75.0, 0.01));
      // Bob: 40 + (10 * 0.4) + (15 * 0.4) = 40 + 4 + 6 = 50
      expect(shares[bob], closeTo(50.0, 0.01));
    });

    test('birthday person gets zero share', () {
      final data = makeData(
        participants: [alice, bob],
        subtotal: 100.0,
        tax: 10.0,
        tipAmount: 15.0,
        total: 125.0,
        personTotals: {alice: 0.0, bob: 100.0},
        birthdayPerson: alice,
      );

      final shares = AssignmentUtils.calculateFinalShares(data);
      expect(shares[alice], equals(0.0));
      expect(shares[bob], closeTo(125.0, 0.01));
    });

    test('splits evenly when nothing assigned', () {
      final data = makeData(
        participants: [alice, bob],
        subtotal: 100.0,
        tax: 10.0,
        tipAmount: 15.0,
        total: 125.0,
        personTotals: {alice: 0.0, bob: 0.0},
      );

      final shares = AssignmentUtils.calculateFinalShares(data);
      expect(shares[alice], closeTo(62.5, 0.01));
      expect(shares[bob], closeTo(62.5, 0.01));
    });

    test('even split excludes birthday person', () {
      final data = makeData(
        participants: [alice, bob, charlie],
        subtotal: 100.0,
        tax: 10.0,
        tipAmount: 15.0,
        total: 125.0,
        personTotals: {alice: 0.0, bob: 0.0, charlie: 0.0},
        birthdayPerson: charlie,
      );

      final shares = AssignmentUtils.calculateFinalShares(data);
      expect(shares[charlie], equals(0.0));
      expect(shares[alice], closeTo(62.5, 0.01));
      expect(shares[bob], closeTo(62.5, 0.01));
    });
  });

  group('AssignmentUtils.calculateInitialAssignments', () {
    test('splits evenly with no items', () {
      final data = makeData(
        participants: [alice, bob],
        items: [],
        subtotal: 100.0,
        tax: 10.0,
        tipAmount: 15.0,
        total: 125.0,
      );

      final result = AssignmentUtils.calculateInitialAssignments(data);
      expect(result.personTotals[alice], closeTo(50.0, 0.01));
      expect(result.personTotals[bob], closeTo(50.0, 0.01));
      expect(result.unassignedAmount, equals(0.0));
    });

    test('excludes birthday person from even split', () {
      final data = makeData(
        participants: [alice, bob, charlie],
        items: [],
        subtotal: 90.0,
        tax: 9.0,
        tipAmount: 9.0,
        total: 108.0,
        birthdayPerson: charlie,
      );

      final result = AssignmentUtils.calculateInitialAssignments(data);
      expect(result.personTotals[charlie], equals(0.0));
      expect(result.personTotals[alice], closeTo(45.0, 0.01));
      expect(result.personTotals[bob], closeTo(45.0, 0.01));
    });

    test('sets full subtotal as unassigned when items exist', () {
      final item = BillItem(name: 'Pizza', price: 20.0, assignments: {});
      final data = makeData(
        participants: [alice, bob],
        items: [item],
        subtotal: 20.0,
        tax: 2.0,
        tipAmount: 3.0,
        total: 25.0,
      );

      final result = AssignmentUtils.calculateInitialAssignments(data);
      expect(result.unassignedAmount, equals(20.0));
      expect(result.personTotals[alice], equals(0.0));
      expect(result.personTotals[bob], equals(0.0));
    });
  });

  group('AssignmentUtils.assignItem', () {
    test('updates person totals after assignment', () {
      final item = BillItem(name: 'Pizza', price: 20.0, assignments: {});
      final data = makeData(
        participants: [alice, bob],
        items: [item],
        subtotal: 20.0,
        tax: 2.0,
        tipAmount: 3.0,
        total: 25.0,
        unassignedAmount: 20.0,
      );

      final result = AssignmentUtils.assignItem(
        data,
        item,
        {alice: 100.0},
      );

      expect(result.personTotals[alice], closeTo(20.0, 0.01));
      expect(result.personTotals[bob], closeTo(0.0, 0.01));
      expect(result.unassignedAmount, closeTo(0.0, 0.01));
    });

    test('splits item between two people', () {
      final item = BillItem(name: 'Pizza', price: 20.0, assignments: {});
      final data = makeData(
        participants: [alice, bob],
        items: [item],
        subtotal: 20.0,
        tax: 2.0,
        tipAmount: 3.0,
        total: 25.0,
        unassignedAmount: 20.0,
      );

      final result = AssignmentUtils.assignItem(
        data,
        item,
        {alice: 50.0, bob: 50.0},
      );

      expect(result.personTotals[alice], closeTo(10.0, 0.01));
      expect(result.personTotals[bob], closeTo(10.0, 0.01));
      expect(result.unassignedAmount, closeTo(0.0, 0.01));
    });
  });

  group('AssignmentUtils.unassignItemsFromBirthdayPerson', () {
    test('removes birthday person and rescales remaining', () {
      final item = BillItem(
        name: 'Pizza',
        price: 30.0,
        assignments: {alice: 33.33, bob: 33.33, charlie: 33.34},
      );
      final data = makeData(
        participants: [alice, bob, charlie],
        items: [item],
        subtotal: 30.0,
        tax: 3.0,
        tipAmount: 3.0,
        total: 36.0,
        personTotals: {alice: 10.0, bob: 10.0, charlie: 10.0},
        birthdayPerson: charlie,
      );

      AssignmentUtils.unassignItemsFromBirthdayPerson(data, charlie);

      // Charlie should be removed from the item assignments
      expect(item.assignments.containsKey(charlie), isFalse);

      // Alice and Bob should each have ~50% now
      expect(item.assignments[alice], closeTo(50.0, 0.5));
      expect(item.assignments[bob], closeTo(50.0, 0.5));
    });

    test('returns unchanged data when birthday person has no assignments', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 50.0, bob: 50.0},
      );
      final data = makeData(
        participants: [alice, bob, charlie],
        items: [item],
        subtotal: 20.0,
        personTotals: {alice: 10.0, bob: 10.0, charlie: 0.0},
      );

      final result = AssignmentUtils.unassignItemsFromBirthdayPerson(
        data,
        charlie,
      );

      // Data should be unchanged
      expect(result.personTotals, equals(data.personTotals));
    });
  });

  group('AssignmentUtils.splitUnassignedAmountEvenly', () {
    test('distributes unassigned amount evenly', () {
      final data = makeData(
        participants: [alice, bob],
        items: [],
        subtotal: 100.0,
        tax: 10.0,
        tipAmount: 15.0,
        total: 125.0,
        personTotals: {alice: 0.0, bob: 0.0},
        unassignedAmount: 100.0,
      );

      final result = AssignmentUtils.splitUnassignedAmountEvenly(data);
      expect(result.personTotals[alice], closeTo(50.0, 0.01));
      expect(result.personTotals[bob], closeTo(50.0, 0.01));
      expect(result.unassignedAmount, equals(0.0));
    });

    test('excludes birthday person from distribution', () {
      final data = makeData(
        participants: [alice, bob, charlie],
        items: [],
        subtotal: 90.0,
        tax: 9.0,
        tipAmount: 9.0,
        total: 108.0,
        personTotals: {alice: 0.0, bob: 0.0, charlie: 0.0},
        unassignedAmount: 90.0,
        birthdayPerson: charlie,
      );

      final result = AssignmentUtils.splitUnassignedAmountEvenly(data);
      expect(result.personTotals[alice], closeTo(45.0, 0.01));
      expect(result.personTotals[bob], closeTo(45.0, 0.01));
      expect(result.personTotals[charlie], equals(0.0));
      expect(result.unassignedAmount, equals(0.0));
    });

    test('returns unchanged when nothing is unassigned', () {
      final data = makeData(
        participants: [alice, bob],
        personTotals: {alice: 50.0, bob: 50.0},
        unassignedAmount: 0.0,
      );

      final result = AssignmentUtils.splitUnassignedAmountEvenly(data);
      expect(result.personTotals[alice], equals(50.0));
      expect(result.personTotals[bob], equals(50.0));
    });

    test('distributes unassigned item percentages with items', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 50.0},
      );
      final data = makeData(
        participants: [alice, bob],
        items: [item],
        subtotal: 20.0,
        tax: 2.0,
        tipAmount: 3.0,
        total: 25.0,
        personTotals: {alice: 10.0, bob: 0.0},
        unassignedAmount: 10.0,
      );

      final result = AssignmentUtils.splitUnassignedAmountEvenly(data);
      expect(result.unassignedAmount, equals(0.0));
      // Both should have received half of the unassigned 50%
      expect(result.personTotals[alice]! + result.personTotals[bob]!,
          closeTo(20.0, 0.01));
    });
  });
}
