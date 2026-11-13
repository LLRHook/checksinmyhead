import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/models/exchange_rate_quote.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/bill_summary_section.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/widgets/currency_section.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/assignment_bottom_bar.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/utils/recent_bills_share_utils.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keep the real tab screen, selector and display models; replace only history I/O.
class FixtureHistory extends RecentBillsManager {
  FixtureHistory(this.bills, AppDatabase db, ApiService api)
    : super.withDependencies(database: db, api: api);
  final List<RecentBillModel> bills;
  @override
  Future<List<RecentBillModel>> getRecentBills({
    bool requireComplete = false,
  }) async => bills;
}

RecentBillModel recordedBill(Map<String, dynamic> row, {bool pending = true}) =>
    RecentBillModel(
      id: 66,
      billName: 'L20 receipt',
      participantNames: const [],
      participantCount: 0,
      total: (row['total'] as num).toDouble(),
      date: DateTime(2026, 11, 12),
      subtotal: 0,
      tax: 0,
      tipAmount: 0,
      color: Colors.blue,
      currencyCode: row['currency'] as String,
      valuationState: pending ? 'pending' : 'legacy',
      savedShares: [
        for (final amount in row['shares'] as List)
          {'name': 'Recorded', 'total': amount},
      ],
    );

void main() {
  final rows =
      (jsonDecode(
                File('../testdata/bill_display_totals.json').readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final row in rows) {
    testWidgets('cent-exact phone surfaces ${row['case']}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final expected = CurrencyFormatter.formatCurrency(
        (row['expected'] as num).toDouble(),
        currencyCode: row['currency'] as String,
      );
      final data =
          BillData()
            ..total = (row['total'] as num).toDouble()
            ..currencyCode = row['currency'] as String;
      addTearDown(data.dispose);
      Future<void> show(Widget child) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder label(String value) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == value,
      );
      await show(
        ChangeNotifierProvider.value(
          value: data,
          child: const BillSummarySection(),
        ),
      );
      final entry = label('Total: $expected');
      expect(entry, findsOneWidget, reason: 'entry summary semantics');
      expect(
        find.descendant(of: entry, matching: find.text(expected)),
        findsOneWidget,
        reason: 'entry summary amount',
      );
      await show(
        AssignmentBottomBar(
          totalBill: data.total,
          currencyCode: data.currencyCode,
          onContinueTap: () {},
        ),
      );
      final footer = label('Total bill: $expected');
      expect(footer, findsOneWidget, reason: 'assignment footer semantics');
      expect(
        find.descendant(of: footer, matching: find.text(expected)),
        findsOneWidget,
        reason: 'assignment footer amount',
      );
      final bill = recordedBill(row);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: BillDetailsScreen(bill: bill)));
      // The existing header pulse repeats indefinitely. Inspect after entry animation.
      await tester.pump(const Duration(seconds: 1));
      expect(
        label('Bill total: $expected'),
        findsOneWidget,
        reason: 'Bill Details semantics',
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.style?.fontSize == 32 && w.data == expected,
        ),
        findsOneWidget,
        reason: 'Bill Details header',
      );
      if (row['currency'] == 'USD') {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: BillDetailsScreen(
              bill: recordedBill(row, pending: false),
              showBillTotalsInUSD: true,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          label('Bill total: $expected'),
          findsOneWidget,
          reason: 'Bill Details USD semantics',
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontSize == 32 && w.data == expected,
          ),
          findsOneWidget,
          reason: 'Bill Details USD header',
        );
      }
      // CurrencySection displays a native total only after a foreign quote exists.
      final previewCode =
          data.currencyCode == 'USD' ? 'EUR' : data.currencyCode;
      data.currencyCode = previewCode;
      data.setExchangeRateQuote(
        ExchangeRateQuote(
          currencyCode: previewCode,
          usdRate: 1,
          rateDate: '2026-11-12',
          source: 'L20 synthetic',
        ),
      );
      await show(
        ChangeNotifierProvider.value(
          value: data,
          child: const CurrencySection(),
        ),
      );
      if (data.total > 0) {
        final native = CurrencyFormatter.formatCurrency(
          (row['expected'] as num).toDouble(),
          currencyCode: previewCode,
        );
        expect(
          find.text('$native = \$${data.usdTotal.toStringAsFixed(2)} USD'),
          findsOneWidget,
          reason: 'currency section native total',
        );
      } else {
        expect(
          find.textContaining('$previewCode 0.00 = '),
          findsNothing,
          reason: 'zero has no conversion total',
        );
      }
      String? shared;
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shared = (call.arguments as Map)['text'] as String?;
        return 'L20 synthetic';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await RecentBillShareUtils.shareBill(bill);
      await tester.pumpAndSettle();
      expect(
        shared,
        contains('Total: $expected\n'),
        reason: 'recorded-history share text',
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final api = ApiService(
        client: MockClient(
          (_) async => throw StateError('L20 display test must not call HTTP'),
        ),
      );
      final history = FixtureHistory([bill], db, api);
      addTearDown(history.dispose);
      final tabs = TabManager.withDependencies(
        database: db,
        receipts: history,
        api: api,
      );
      addTearDown(tabs.dispose);
      Future<void> tab(List<int> ids, {bool pending = true}) async {
        history.bills[0] = recordedBill(row, pending: pending);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: TabDetailScreen(
              tab: AppTab(
                name: 'L20 tab',
                createdAt: DateTime(2026, 11, 12),
                billIds: ids,
              ),
              database: db,
              billsManager: history,
              tabManager: tabs,
              apiService: api,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tab([66]);
      final card = find.byKey(const ValueKey('bill_66'));
      final pending =
          '${row['currency']} ${(row['expected'] as num).toStringAsFixed(2)} · USD pending';
      expect(
        find.descendant(of: card, matching: find.text(pending)),
        findsOneWidget,
        reason: 'tab native/pending bill row',
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.startsWith(
                    '${bill.billName}, ${row['currency']} ${(row['expected'] as num).toStringAsFixed(2)}, USD pending, ${bill.formattedDate}',
                  ) ??
                  false),
        ),
        findsOneWidget,
        reason: 'tab native/pending semantics',
      );
      if (row['currency'] == 'USD') {
        await tab([66], pending: false);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('bill_66')),
            matching: find.text(expected),
          ),
          findsOneWidget,
          reason: 'tab USD bill row',
        );
      }
      await tab([]);
      await tester.tap(find.byTooltip('More tab actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add existing bill'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(CheckboxListTile),
          matching: find.text('${bill.formattedDate} • $expected'),
        ),
        findsOneWidget,
        reason: 'add-existing selector',
      );
      expect(bill.total, row['total']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test('Recent Bills model keeps the server forty-cent allocation visible', () {
    final data = BillData();
    addTearDown(data.dispose);
    data.subtotalController.text = '0.35';
    data.taxController.text = '0.02';
    data.setTipPercentage(10);
    expect(data.total, 0.40499999999999997);
    final bill = recordedBill({
      'total': data.total,
      'shares': [0.40],
      'currency': 'USD',
    });
    expect(CurrencyFormatter.formatCurrency(bill.displayTotal), r'$0.40');
    expect(bill.total, data.total);
    expect(bill.recordedShares.single['total'], 0.40);
  });
}
