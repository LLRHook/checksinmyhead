import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';

RecentBill _makeRecentBill({
  int id = 1,
  String billName = 'Test Bill',
  List<String> participants = const ['Alice', 'Bob'],
  double total = 30.0,
  double subtotal = 20.0,
  double tax = 5.0,
  double tipAmount = 5.0,
  double? tipPercentage = 25.0,
  String? items,
  int colorValue = 0xFF328983,
}) {
  return RecentBill(
    id: id,
    billName: billName,
    participants: jsonEncode(participants),
    participantCount: participants.length,
    total: total,
    date: '2025-01-01',
    subtotal: subtotal,
    tax: tax,
    tipAmount: tipAmount,
    tipPercentage: tipPercentage,
    items: items,
    colorValue: colorValue,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('RecentBillModel.generatePersonShares', () {
    test('splits total equally when no items', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: ['Alice', 'Bob'],
        total: 30.0,
      ));

      final shares = bill.generatePersonShares();
      expect(shares.length, equals(2));
      for (final entry in shares.entries) {
        expect(entry.value, closeTo(15.0, 0.01));
      }
    });

    test('returns empty map when no participants and no items', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: [],
        total: 30.0,
      ));

      final shares = bill.generatePersonShares();
      expect(shares, isEmpty);
    });

    test('handles single participant', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: ['Alice'],
        total: 50.0,
      ));

      final shares = bill.generatePersonShares();
      expect(shares.length, equals(1));
      expect(shares.values.first, closeTo(50.0, 0.01));
    });

    test('calculates shares from item assignments', () {
      final items = jsonEncode([
        {
          'name': 'Pizza',
          'price': 20.0,
          'assignments': {'Alice': 75.0, 'Bob': 25.0},
        },
      ]);

      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: ['Alice', 'Bob'],
        total: 30.0,
        subtotal: 20.0,
        tax: 5.0,
        tipAmount: 5.0,
        items: items,
      ));

      final shares = bill.generatePersonShares();
      // Alice: 75% of $20 = $15, Bob: 25% of $20 = $5
      // Tax+tip = $10, distributed proportionally
      // Alice: $15 + (15/20 * 10) = $15 + $7.50 = $22.50
      // Bob: $5 + (5/20 * 10) = $5 + $2.50 = $7.50
      final aliceShare = shares.entries
          .firstWhere((e) => e.key.name == 'Alice')
          .value;
      final bobShare = shares.entries
          .firstWhere((e) => e.key.name == 'Bob')
          .value;

      expect(aliceShare, closeTo(22.50, 0.01));
      expect(bobShare, closeTo(7.50, 0.01));
    });

    test('falls back to equal split when items have no assignments', () {
      final items = jsonEncode([
        {'name': 'Pizza', 'price': 20.0, 'assignments': {}},
      ]);

      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: ['Alice', 'Bob'],
        total: 30.0,
        items: items,
      ));

      final shares = bill.generatePersonShares();
      final aliceShare = shares.entries
          .firstWhere((e) => e.key.name == 'Alice')
          .value;
      final bobShare = shares.entries
          .firstWhere((e) => e.key.name == 'Bob')
          .value;

      expect(aliceShare, closeTo(15.0, 0.01));
      expect(bobShare, closeTo(15.0, 0.01));
    });

    test('handles zero total without division error', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: ['Alice', 'Bob'],
        total: 0.0,
        subtotal: 0.0,
        tax: 0.0,
        tipAmount: 0.0,
      ));

      final shares = bill.generatePersonShares();
      expect(shares.length, equals(2));
      for (final entry in shares.entries) {
        expect(entry.value, equals(0.0));
      }
    });
  });

  group('RecentBillModel.participantSummary', () {
    test('shows "No participants" when empty', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: [],
      ));
      expect(bill.participantSummary, equals('No participants'));
    });

    test('joins two names with ampersand', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: ['Alice', 'Bob'],
      ));
      expect(bill.participantSummary, equals('Alice & Bob'));
    });

    test('shows count for 3+ participants', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        participants: ['Alice', 'Bob', 'Charlie', 'Dana'],
      ));
      expect(bill.participantSummary, equals('Alice, Bob & 2 more'));
    });
  });

  group('RecentBillModel.fromData', () {
    test('parses tip percentage from stored value', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        tipPercentage: 18.0,
      ));
      expect(bill.tipPercentage, equals(18.0));
    });

    test('calculates tip percentage when not stored', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        subtotal: 100.0,
        tipAmount: 20.0,
        tipPercentage: null,
      ));
      expect(bill.tipPercentage, closeTo(20.0, 0.01));
    });

    test('handles zero subtotal when calculating tip percentage', () {
      final bill = RecentBillModel.fromData(_makeRecentBill(
        subtotal: 0.0,
        tipAmount: 0.0,
        tipPercentage: null,
      ));
      expect(bill.tipPercentage, equals(0.0));
    });
  });
}
