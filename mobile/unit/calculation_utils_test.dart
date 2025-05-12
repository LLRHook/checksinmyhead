import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/calculation_utils.dart';

void main() {
  group('CalculationUtils tests', () {
    // Common test people
    final alice = Person(name: 'Alice', color: Colors.blue);
    final bob = Person(name: 'Bob', color: Colors.red);
    final charlie = Person(name: 'Charlie', color: Colors.green);
    
    test('calculatePersonAmounts with itemized approach', () {
      // Create test data with items
      final items = [
        BillItem(
          name: 'Pizza',
          price: 20.0,
          assignments: {
            alice: 50.0, // $10.00
            bob: 50.0,   // $10.00
          },
        ),
        BillItem(
          name: 'Salad',
          price: 10.0,
          assignments: {
            alice: 100.0, // $10.00
          },
        ),
      ];
      
      final participants = [alice, bob];
      final personShares = {
        alice: 20.0, // Not used in itemized approach
        bob: 10.0,   // Not used in itemized approach
      };
      
      // Calculate for Alice
      final aliceAmounts = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: 30.0,
        tax: 3.0,      // 10% of subtotal
        tipAmount: 4.5, // 15% of subtotal
        birthdayPerson: null,
      );
      
      // Alice's subtotal: Pizza $10 + Salad $10 = $20
      expect(aliceAmounts['subtotal'], 20.0);
      
      // Alice's tax: $20/$30 * $3 = $2
      expect(aliceAmounts['tax'], 2.0);
      
      // Alice's tip: $20/$30 * $4.5 = $3
      expect(aliceAmounts['tip'], 3.0);
      
      // Alice's total: $20 + $2 + $3 = $25
      expect(aliceAmounts['total'], 25.0);
      
      // Calculate for Bob
      final bobAmounts = CalculationUtils.calculatePersonAmounts(
        person: bob,
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: 30.0,
        tax: 3.0,
        tipAmount: 4.5,
        birthdayPerson: null,
      );
      
      // Bob's subtotal: Pizza $10 = $10
      expect(bobAmounts['subtotal'], 10.0);
      
      // Bob's tax: $10/$30 * $3 = $1
      expect(bobAmounts['tax'], 1.0);
      
      // Bob's tip: $10/$30 * $4.5 = $1.5
      expect(bobAmounts['tip'], 1.5);
      
      // Bob's total: $10 + $1 + $1.5 = $12.5
      expect(bobAmounts['total'], 12.5);
    });
    
    test('calculatePersonAmounts with proportional approach (no items)', () {
      // Create test data without items
      final items = <BillItem>[];
      final participants = [alice, bob, charlie];
      final personShares = {
        alice: 20.0, // $20.00
        bob: 10.0,   // $10.00
        charlie: 10.0, // $10.00
      };
      
      // Calculate for Alice
      final aliceAmounts = CalculationUtils.calculatePersonAmounts(
        person: alice,
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: 40.0,
        tax: 4.0,      // 10% of subtotal
        tipAmount: 6.0, // 15% of subtotal
        birthdayPerson: null,
      );
      
      // Total bill: $40 + $4 + $6 = $50
      // Alice's proportion: $20 / $50 = 0.4
      
      // Alice's subtotal: 0.4 * $40 = $16
      expect(aliceAmounts['subtotal'], closeTo(16.0, 0.01));
      
      // Alice's tax: 0.4 * $4 = $1.6
      expect(aliceAmounts['tax'], closeTo(1.6, 0.01));
      
      // Alice's tip: 0.4 * $6 = $2.4
      expect(aliceAmounts['tip'], closeTo(2.4, 0.01));
      
      // Alice's total: $16 + $1.6 + $2.4 = $20
      expect(aliceAmounts['total'], closeTo(20.0, 0.01));
    });
    
    test('calculatePersonAmounts with person having \$0 share', () {
      // Create test data
      final items = <BillItem>[]; // No items
      final participants = [alice, bob];
      final personShares = {
        alice: 30.0,
        bob: 0.0, // Zero share
      };
      
      // Calculate for Bob
      final bobAmounts = CalculationUtils.calculatePersonAmounts(
        person: bob,
        participants: participants,
        personShares: personShares,
        items: items,
        subtotal: 30.0,
        tax: 3.0,
        tipAmount: 4.5,
        birthdayPerson: null,
      );
      
      // Bob's amounts should all be zero
      expect(bobAmounts['subtotal'], 0.0);
      expect(bobAmounts['tax'], 0.0);
      expect(bobAmounts['tip'], 0.0);
      expect(bobAmounts['total'], 0.0);
    });
  });
}