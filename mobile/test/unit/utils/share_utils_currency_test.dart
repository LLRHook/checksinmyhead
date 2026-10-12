import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:flutter/material.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('share text labels original non-USD receipt amounts', () async {
    SharedPreferences.setMockInitialValues({});

    final text = await ShareUtils.generateShareText(
      participants: const [],
      personShares: const {},
      items: [BillItem(name: 'Coffee', price: 4.5, assignments: {})],
      subtotal: 4.5,
      tax: 0,
      tipAmount: 0,
      total: 4.5,
      birthdayPerson: null,
      tipPercentage: 0,
      isCustomTipAmount: false,
      showAllItems: true,
      showPersonItems: false,
      showBreakdown: true,
      currencyCode: 'EUR',
    );

    expect(text, contains('Total: EUR 4.50'));
    expect(text, contains('• Coffee: EUR 4.50'));
    expect(text, isNot(contains(r'$4.50')));
  });

  test('share details match reconstructed people by name', () async {
    SharedPreferences.setMockInitialValues({});
    final person = Person(name: 'Alice', color: Colors.blue);

    final text = await ShareUtils.generateShareText(
      participants: [person],
      personShares: {Person(name: 'alice', color: Colors.red): 4.5},
      items: [
        BillItem(
          name: 'Coffee',
          price: 4.5,
          assignments: {Person(name: 'ALICE', color: Colors.green): 100},
        ),
      ],
      subtotal: 4.5,
      tax: 0.5,
      tipAmount: 0.9,
      total: 5.9,
      birthdayPerson: null,
      tipPercentage: 20,
      isCustomTipAmount: false,
      showAllItems: false,
      showPersonItems: true,
      showBreakdown: false,
      currencyCode: 'EUR',
    );

    expect(text, contains('• Alice: EUR 4.50'));
    expect(text, contains('  - Coffee: EUR 4.50'));
    expect(text, contains('  + Tax & tip: EUR 1.40'));
  });
}
