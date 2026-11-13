import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bill_total_card.dart';
import 'package:checks_frontend/screens/recent_bills/components/recent_bill_card.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases =
      jsonDecode(
            File('../testdata/bill_display_totals.json').readAsStringSync(),
          )
          as List;
  for (final row in cases.cast<Map<String, dynamic>>()) {
    testWidgets('cent-exact summary ${row['case']}', (tester) async {
      final amounts = (row['shares'] as List).cast<num>();
      final people = [
        for (var i = 0; i < amounts.length; i++)
          Person(name: 'Person $i', color: Colors.blue),
      ];
      final data = BillSummaryData(
        participants: people,
        personShares: {
          for (var i = 0; i < people.length; i++)
            people[i]: amounts[i].toDouble(),
        },
        items: const [],
        subtotal: (row['total'] as num).toDouble(),
        tax: 0,
        tipAmount: 0,
        total: (row['total'] as num).toDouble(),
        currencyCode: row['currency'] as String,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BillTotalCard(data: data))),
      );
      final expected = CurrencyFormatter.formatCurrency(
        (row['expected'] as num).toDouble(),
        currencyCode: row['currency'] as String,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.style?.fontSize == 32 &&
              widget.data == expected,
        ),
        findsOneWidget,
      );
      expect(data.total, row['total']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'half-cent recent card uses recorded shares without changing the receipt',
    (tester) async {
      final bill = RecentBillModel(
        id: 66,
        billName: 'L20 synthetic',
        participantNames: const ['Alex', 'Sam', 'Cara'],
        participantCount: 3,
        total: 24.884999999999998,
        date: DateTime(2026, 11, 10),
        subtotal: 19.75,
        tax: 1.58,
        tipAmount: 3.555,
        color: Colors.blue,
        savedShares: const [
          {'name': 'Alex', 'total': 16.49},
          {'name': 'Sam', 'total': 4.2},
          {'name': 'Cara', 'total': 4.2},
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentBillCard(
              bill: bill,
              onDeleted: () {},
              onRefreshNeeded: () {},
            ),
          ),
        ),
      );
      expect(find.text(r'$24.89'), findsOneWidget);
      expect(bill.total, 24.884999999999998);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('half-cent copied summary total matches its unchanged shares', () async {
    SharedPreferences.setMockInitialValues({});
    final person = Person(name: 'Alex', color: Colors.blue);
    final text = await ShareUtils.generateShareText(
      participants: [person],
      personShares: {person: 24.89},
      items: const [],
      subtotal: 19.75,
      tax: 1.58,
      tipAmount: 3.555,
      total: 24.884999999999998,
      birthdayPerson: null,
      tipPercentage: 18,
      isCustomTipAmount: false,
      showAllItems: false,
      showPersonItems: false,
      showBreakdown: false,
    );
    expect(text, contains(r'Total: $24.89'));
    expect(text, contains(r'Alex: $24.89'));
  });
}
