import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bottom_bar.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/continue_button.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/receipt_review_sheet.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'save_receipt_test.dart' show Harness, draft;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final cancel in [true, false]) {
    testWidgets(
      'Done ${cancel ? 'cancel' : 'EUR offline'} reports durable outcome through actual handler',
      (tester) async {
        final h = Harness()..replay = false;
        addTearDown(h.db.close);
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (c) {
                  context = c;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        SaveReceiptResult? presented;
        final result = await tester.runAsync(
          () => DoneButtonHandler.handleDone(
            context,
            data: draft(),
            operationHandle: 'widget-op',
            manager: h.owner,
            confirmName: () async => cancel ? '' : 'Confirmed EUR',
            presentSaved: (result, data) async {
              presented = result;
            },
            navigateHome: () {},
          ),
        );
        await tester.pumpAndSettle();
        final rows = await tester.runAsync(h.db.getRecentBills);
        expect(rows, hasLength(cancel ? 0 : 1));
        if (cancel) {
          expect(result, isNull);
          expect(presented, isNull);
        } else {
          expect(result!.localId, rows!.single.id);
          expect(rows.single.currencyCode, 'EUR');
          expect(presented!.message, contains('Saved on this device'));
        }
        expect(h.posts, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'notification share and navigation failures cannot undo a committed Done',
    (tester) async {
      final h = Harness();
      addTearDown(h.db.close);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final prior = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = prior);
      h.owner.addListener(() => throw StateError('synthetic listener'));
      final result = await tester.runAsync(
        () => DoneButtonHandler.handleDone(
          context,
          data: draft(),
          operationHandle: 'presentation-failure',
          manager: h.owner,
          confirmName: () async => 'Saved EUR',
          presentSaved:
              (_, data) async => throw StateError('synthetic share failure'),
          navigateHome: () => throw StateError('synthetic navigation failure'),
        ),
      );
      await tester.pumpAndSettle();
      expect(result!.publication, PublicationState.published);
      expect(h.posts, 1);
      final rows = await tester.runAsync(h.db.getRecentBills);
      expect(rows, hasLength(1));
      expect(rows!.single.shareUrl, result.shareUrl);
      final repeated = await tester.runAsync(
        () => h.save('presentation-failure'),
      );
      expect(repeated!.localId, result.localId);
      expect(h.posts, 1);
    },
  );
  testWidgets(
    'foreign offline Continue remains available after explicit currency confirmation',
    (tester) async {
      final data = BillData();
      addTearDown(data.dispose);
      data.selectCurrency('PEN');
      data.setExchangeRateError('synthetic offline');
      var continued = false;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: data,
          child: MaterialApp(
            home: Scaffold(
              body: ContinueButton(
                onPressed: () {
                  continued = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(continued, true);
      expect(data.currencyConfirmed, true);
      expect(data.hasUsableExchangeRate, false);
    },
  );
  test('ambiguous dollar scan invalidates earlier USD confirmation', () {
    final data = BillData();
    addTearDown(data.dispose);
    data.selectCurrency('USD');
    data.populateFromScan(
      ParsedReceipt(
        items: [ParsedItem(name: 'Unit', price: 10, quantity: 1)],
        currencySymbol: r'$',
      ),
    );
    expect(data.currencyConfirmed, false);
  });
  testWidgets(
    'receipt review preserves explicit PEN scan evidence but still needs confirmation',
    (tester) async {
      final receipt = ParsedReceipt(
        items: [ParsedItem(name: 'Unit', price: 10, quantity: 1)],
        currencyCode: 'PEN',
        currencySymbol: 'S/',
        currencyConfidence: .9,
      );
      ParsedReceipt? reviewed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (c) => TextButton(
                    onPressed: () async {
                      reviewed = await showModalBottomSheet<ParsedReceipt>(
                        context: c,
                        isScrollControlled: true,
                        builder: (_) => ReceiptReviewSheet(receipt: receipt),
                      );
                    },
                    child: const Text('Review'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to Bill'));
      await tester.pumpAndSettle();
      expect(reviewed!.currencyCode, 'PEN');
      expect(reviewed!.currencySymbol, 'S/');
      expect(reviewed!.currencyConfidence, .9);
      final data = BillData();
      addTearDown(data.dispose);
      data.populateFromScan(reviewed!);
      expect(data.currencyCode, 'PEN');
      expect(data.currencyConfirmed, false);
    },
  );
}
