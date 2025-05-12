import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';

void main() {
  group('BillItem model tests', () {
    // Common test people
    final alice = Person(name: 'Alice', color: Colors.blue);
    final bob = Person(name: 'Bob', color: Colors.red);
    final charlie = Person(name: 'Charlie', color: Colors.green);

    test('BillItem constructor creates instance with correct properties', () {
      final assignments = {alice: 70.0, bob: 30.0};
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: assignments,
      );

      expect(item.name, 'Pizza');
      expect(item.price, 20.0);
      expect(item.assignments, assignments);
    });

    test('amountForPerson calculates correct portion based on percentage', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {
          alice: 75.0, // 75% of $20 = $15
          bob: 25.0, // 25% of $20 = $5
        },
      );

      expect(item.amountForPerson(alice), 15.0);
      expect(item.amountForPerson(bob), 5.0);
    });

    test('amountForPerson returns 0 for unassigned person', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 75.0, bob: 25.0},
      );

      expect(item.amountForPerson(charlie), 0.0);
    });

    test('amountForPerson returns 0 when person assigned 0%', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 75.0, bob: 25.0, charlie: 0.0},
      );

      expect(item.amountForPerson(charlie), 0.0);
    });

    test('amountForPerson handles decimal percentages correctly', () {
      final item = BillItem(
        name: 'Shared dish',
        price: 10.0,
        assignments: {alice: 33.33, bob: 33.33, charlie: 33.34},
      );

      expect(item.amountForPerson(alice), closeTo(3.333, 0.001));
      expect(item.amountForPerson(bob), closeTo(3.333, 0.001));
      expect(item.amountForPerson(charlie), closeTo(3.334, 0.001));

      // Verify total sums to the item price (within rounding error)
      final total =
          item.amountForPerson(alice) +
          item.amountForPerson(bob) +
          item.amountForPerson(charlie);
      expect(total, closeTo(10.0, 0.001));
    });

    test('copyWith creates a new instance with updated values', () {
      final originalItem = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 100.0},
      );

      final newAssignments = {alice: 50.0, bob: 50.0};

      final updatedItem = originalItem.copyWith(
        name: 'Deluxe Pizza',
        price: 25.0,
        assignments: newAssignments,
      );

      // Verify updated properties
      expect(updatedItem.name, 'Deluxe Pizza');
      expect(updatedItem.price, 25.0);
      expect(updatedItem.assignments, newAssignments);

      // Verify it's a different instance
      expect(identical(originalItem, updatedItem), false);
    });

    test('copyWith preserves values not explicitly changed', () {
      final originalItem = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 100.0},
      );

      // Only update name
      final updatedItem = originalItem.copyWith(name: 'Deluxe Pizza');

      expect(updatedItem.name, 'Deluxe Pizza');
      expect(updatedItem.price, 20.0);
      expect(updatedItem.assignments, {alice: 100.0});
    });

    test('assignments can be modified after creation', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.0,
        assignments: {alice: 100.0},
      );

      // Change assignments
      item.assignments = {bob: 100.0};

      expect(item.assignments, {bob: 100.0});
      expect(item.amountForPerson(alice), 0.0);
      expect(item.amountForPerson(bob), 20.0);
    });
  });
}
