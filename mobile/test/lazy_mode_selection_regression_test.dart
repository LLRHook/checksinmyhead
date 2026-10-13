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

  group('lazyAssignmentsEqual', () {
    test('compares splits without depending on participant order', () {
      expect(
        lazyAssignmentsEqual(
          [
            {'person_name': 'Alex', 'percentage': 40},
            {'person_name': 'Sam', 'percentage': 60},
          ],
          [
            {'person_name': 'sam', 'percentage': 60},
            {'person_name': 'alex', 'percentage': 40},
          ],
        ),
        isTrue,
      );
    });

    test('detects a changed share percentage', () {
      expect(
        lazyAssignmentsEqual(
          [
            {'person_name': 'Alex', 'percentage': 35},
            {'person_name': 'Sam', 'percentage': 65},
          ],
          [
            {'person_name': 'Alex', 'percentage': 40},
            {'person_name': 'Sam', 'percentage': 60},
          ],
        ),
        isFalse,
      );
    });
  });

  test('a partially paid split is locked before assignment edits', () {
    expect(
      hasPaidLazyAssignment(
        [
          {'person_name': 'Alex', 'percentage': 40},
          {'person_name': 'Sam', 'percentage': 60},
        ],
        [
          {'person_name': 'Alex', 'paid': true},
          {'person_name': 'Sam', 'paid': false},
        ],
      ),
      isTrue,
    );
  });

  group('createLazySplitAssignments', () {
    test('assigns the chosen share and divides the remainder evenly', () {
      expect(createLazySplitAssignments('Me', 'Alex, Sam', 70), [
        {'person_name': 'Me', 'percentage': 70.0},
        {'person_name': 'Alex', 'percentage': 15.0},
        {'person_name': 'Sam', 'percentage': 15.0},
      ]);
    });

    test('deduplicates names and requires someone else to share with', () {
      expect(createLazySplitAssignments('Me', 'Me, Alex, alex', 25), [
        {'person_name': 'Me', 'percentage': 25.0},
        {'person_name': 'Alex', 'percentage': 75.0},
      ]);
      expect(createLazySplitAssignments('Me', 'Me', 50), isNull);
    });
  });

  test('removing one person reallocates the whole item to the others', () {
    final remaining = removeLazyAssignment([
      {'person_name': 'Me', 'percentage': 35},
      {'person_name': 'Alex', 'percentage': 25},
      {'person_name': 'Sam', 'percentage': 40},
    ], 'Me');
    expect(remaining[0]['person_name'], 'Alex');
    expect(remaining[0]['percentage'], closeTo(38.4615, 0.001));
    expect(remaining[1]['person_name'], 'Sam');
    expect(remaining[1]['percentage'], closeTo(61.5385, 0.001));
    expect(
      removeLazyAssignment([
        {'person_name': 'Me', 'percentage': 100},
      ], 'Me'),
      isEmpty,
    );
  });
}
