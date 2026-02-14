import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/calculation_utils.dart';

void main() {
  final alice = Person(name: 'Alice', color: Colors.blue);
  final bob = Person(name: 'Bob', color: Colors.red);

  group('CalculationUtils.calculatePersonAmounts - itemized', () {
    test('calculates correct amounts for 50/50 split', () {
      final item = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 50.0, bob: 50.0},
      );

      final result = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: [alice, bob],
        personShares: {alice: 10.0, bob: 10.0},
        items: [item],
        subtotal: 20.00,
        tax: 2.00,
        tipAmount: 4.00,
        birthdayPerson: null,
      );

      expect(result['subtotal'], closeTo(10.00, 0.01));
      expect(result['tax'], closeTo(1.00, 0.01));
      expect(result['tip'], closeTo(2.00, 0.01));
      expect(result['total'], closeTo(13.00, 0.01));
    });

    test('handles person with no items assigned', () {
      final item = BillItem(
        name: 'Steak',
        price: 50.00,
        assignments: {alice: 100.0},
      );

      final result = CalculationUtils.calculatePersonAmounts(
        person: bob,
        participants: [alice, bob],
        personShares: {alice: 50.0, bob: 0.0},
        items: [item],
        subtotal: 50.00,
        tax: 5.00,
        tipAmount: 10.00,
        birthdayPerson: null,
      );

      expect(result['subtotal'], equals(0.0));
      expect(result['tax'], equals(0.0));
      expect(result['tip'], equals(0.0));
      expect(result['total'], equals(0.0));
    });

    test('sums multiple items for one person', () {
      final pizza = BillItem(
        name: 'Pizza',
        price: 20.00,
        assignments: {alice: 100.0},
      );
      final salad = BillItem(
        name: 'Salad',
        price: 10.00,
        assignments: {alice: 100.0},
      );

      final result = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: [alice, bob],
        personShares: {alice: 30.0, bob: 0.0},
        items: [pizza, salad],
        subtotal: 30.00,
        tax: 3.00,
        tipAmount: 6.00,
        birthdayPerson: null,
      );

      expect(result['subtotal'], closeTo(30.00, 0.01));
      expect(result['tax'], closeTo(3.00, 0.01));
      expect(result['tip'], closeTo(6.00, 0.01));
      expect(result['total'], closeTo(39.00, 0.01));
    });
  });

  group('CalculationUtils.calculatePersonAmounts - proportional (no items)',
      () {
    test('calculates correct proportional split', () {
      final result = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: [alice, bob],
        personShares: {alice: 15.0, bob: 15.0},
        items: [],
        subtotal: 20.00,
        tax: 2.00,
        tipAmount: 8.00,
        birthdayPerson: null,
      );

      expect(result['total'], closeTo(15.0, 0.01));
    });

    test('handles zero subtotal without division error', () {
      final result = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: [alice, bob],
        personShares: {alice: 0.0, bob: 0.0},
        items: [],
        subtotal: 0.0,
        tax: 0.0,
        tipAmount: 0.0,
        birthdayPerson: null,
      );

      expect(result['subtotal'], equals(0.0));
      expect(result['tax'], equals(0.0));
      expect(result['tip'], equals(0.0));
      expect(result['total'], equals(0.0));
    });

    test('handles zero subtotal with nonzero tax/tip', () {
      // Edge case: subtotal is 0 but tax/tip exist (shouldn't happen in practice
      // but guards against division by zero in proportion calculation)
      final result = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: [alice, bob],
        personShares: {alice: 5.0, bob: 5.0},
        items: [],
        subtotal: 0.0,
        tax: 2.0,
        tipAmount: 3.0,
        birthdayPerson: null,
      );

      // With zero subtotal, personSubtotal is 0, proportion is 0
      expect(result['subtotal'], equals(0.0));
      expect(result['tax'], equals(0.0));
      expect(result['tip'], equals(0.0));
      expect(result['total'], equals(0.0));
    });

    test('birthday person gets zero', () {
      final result = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: [alice, bob],
        personShares: {alice: 0.0, bob: 30.0},
        items: [],
        subtotal: 20.00,
        tax: 2.00,
        tipAmount: 8.00,
        birthdayPerson: alice,
      );

      expect(result['subtotal'], equals(0.0));
      expect(result['tax'], equals(0.0));
      expect(result['tip'], equals(0.0));
      expect(result['total'], equals(0.0));
    });
  });
}
