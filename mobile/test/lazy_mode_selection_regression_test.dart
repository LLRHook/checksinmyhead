import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/lazy_bill_claim_state.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/bill_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owner selection distinguishes duplicate receipt item names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    final items = [
      BillItem(name: 'Beer', price: 6, assignments: {}),
      BillItem(name: 'Beer', price: 6, assignments: {}),
      BillItem(name: 'Beer', price: 6, assignments: {}),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: BillSummaryScreen(
          participants: const [],
          personShares: const {},
          items: items,
          subtotal: 18,
          tax: 0,
          tipAmount: 0,
          total: 18,
          lazyMode: true,
        ),
      ),
    );

    final tiles = find.byType(CheckboxListTile);
    expect(tiles, findsNWidgets(3));
    await tester.tap(tiles.first);
    await tester.pump();

    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes.map((checkbox) => checkbox.value), [true, false, false]);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  group('canChangeLazyBillSelection', () {
    test('blocks all item changes after payment', () {
      expect(canChangeLazyBillSelection(saving: false, paid: true), isFalse);
    });

    test('blocks item changes while a review is saving', () {
      expect(canChangeLazyBillSelection(saving: true, paid: false), isFalse);
    });

    test('allows item changes before payment when idle', () {
      expect(canChangeLazyBillSelection(saving: false, paid: false), isTrue);
    });
  });
}
