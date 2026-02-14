import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';

void main() {
  final alice = Person(name: 'Alice', color: Colors.blue);
  final bob = Person(name: 'Bob', color: Colors.red);

  group('BillItem.amountForPerson', () {
    test('returns correct amount for assigned person', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 50.0, bob: 50.0},
      );
      expect(item.amountForPerson(alice), equals(10.00));
      expect(item.amountForPerson(bob), equals(10.00));
    });

    test('returns 0 for unassigned person', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 100.0},
      );
      expect(item.amountForPerson(bob), equals(0.0));
    });

    test('returns full price for 100% assignment', () {
      final item = BillItem(
        name: 'Steak',
        price: 45.99,
        assignments: {alice: 100.0},
      );
      expect(item.amountForPerson(alice), closeTo(45.99, 0.001));
    });

    test('returns 0 when assignment is 0%', () {
      final item = BillItem(
        name: 'Water',
        price: 5.00,
        assignments: {alice: 0.0},
      );
      expect(item.amountForPerson(alice), equals(0.0));
    });

    test('handles three-way split', () {
      final charlie = Person(name: 'Charlie', color: Colors.green);
      final item = BillItem(
        name: 'Nachos',
        price: 15.00,
        assignments: {alice: 33.33, bob: 33.33, charlie: 33.34},
      );
      final total =
          item.amountForPerson(alice) +
          item.amountForPerson(bob) +
          item.amountForPerson(charlie);
      expect(total, closeTo(15.00, 0.01));
    });

    test('handles zero price item', () {
      final item = BillItem(
        name: 'Free Bread',
        price: 0.0,
        assignments: {alice: 100.0},
      );
      expect(item.amountForPerson(alice), equals(0.0));
    });

    test('handles empty assignments map', () {
      final item = BillItem(name: 'Salad', price: 12.00, assignments: {});
      expect(item.amountForPerson(alice), equals(0.0));
    });
  });

  group('BillItem.copyWith', () {
    test('preserves all fields when no arguments given', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 100.0},
      );
      final copy = item.copyWith();
      expect(copy.name, equals('Pizza'));
      expect(copy.price, equals(20.00));
      expect(copy.assignments, equals({alice: 100.0}));
    });

    test('updates name only', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 100.0},
      );
      final copy = item.copyWith(name: 'Large Pizza');
      expect(copy.name, equals('Large Pizza'));
      expect(copy.price, equals(20.00));
    });

    test('updates price only', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 100.0},
      );
      final copy = item.copyWith(price: 25.00);
      expect(copy.price, equals(25.00));
      expect(copy.name, equals('Pizza'));
    });

    test('updates assignments only', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 100.0},
      );
      final copy = item.copyWith(assignments: {bob: 100.0});
      expect(copy.assignments, equals({bob: 100.0}));
      expect(copy.name, equals('Pizza'));
    });
  });
}
