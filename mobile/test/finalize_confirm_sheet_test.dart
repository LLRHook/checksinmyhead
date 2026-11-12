import 'dart:async';
import 'dart:convert';

import 'package:checks_frontend/config/theme.dart';
import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness;

/// The layout cases open the production sheet through the production
/// `showFinalizeConfirmSheet` route. The confirmation cases go through the real
/// Tab detail screen, tab manager, API client and database.

const personCount = 12;

/// Distinct amounts, so each settlement row is identified by its money text.
double amountFor(int person) => 10.25 + person;
String money(double value) => '\$${value.toStringAsFixed(2)}';

/// Labels in the two forms Tab detail produces. Insertion order is ascending;
/// the sheet shows the largest amount first.
final personTotals = <String, double>{
  for (var person = 1; person <= personCount; person++)
    'Guest ${person.toString().padLeft(2, '0')} · ${person.isEven ? 'member #$person' : 'receipt 1 #$person'}':
        amountFor(person),
};
final expectedMoney = [
  for (var person = personCount; person >= 1; person--)
    money(amountFor(person)),
];

class Display {
  const Display(this.name, this.size, [this.inset = EdgeInsets.zero]);
  final String name;
  final Size size;
  final EdgeInsets inset;
}

const sePortrait = Display(
  '320x568 portrait',
  Size(320, 568),
  EdgeInsets.only(top: 20),
);
const displays = [
  sePortrait,
  Display('375x667 portrait', Size(375, 667), EdgeInsets.only(top: 20)),
  Display('568x320 landscape', Size(568, 320)),
  Display(
    '812x375 landscape with side insets',
    Size(812, 375),
    EdgeInsets.only(left: 44, right: 44, bottom: 21),
  ),
];
const textScales = [1.0, 2.0, 3.0];

void useDisplay(WidgetTester tester, Display display) {
  final padding = FakeViewPadding(
    left: display.inset.left,
    top: display.inset.top,
    right: display.inset.right,
    bottom: display.inset.bottom,
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = display.size;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

Widget scaled(double textScale, Widget home) => MaterialApp(
  theme: AppTheme.lightTheme,
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
  home: home,
);

/// What the opener received when the sheet closed.
class SheetResult {
  bool closed = false;
  bool? value;
}

Future<SheetResult> openSheet(
  WidgetTester tester,
  Display display,
  double textScale, {
  Map<String, double>? totals,
}) async {
  useDisplay(tester, display);
  final result = SheetResult();
  await tester.pumpWidget(
    scaled(
      textScale,
      Scaffold(
        body: Builder(
          builder:
              (context) => Center(
                child: IconButton(
                  icon: const Icon(Icons.lock_outline),
                  onPressed: () async {
                    result.value = await showFinalizeConfirmSheet(
                      context,
                      totals ?? personTotals,
                    );
                    result.closed = true;
                  },
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.lock_outline));
  await tester.pumpAndSettle();
  expect(inSheet(find.text('Finalize Tab')), findsOneWidget);
  return result;
}

Finder inSheet(Finder matching) =>
    find.descendant(of: find.byType(BottomSheet), matching: matching);

Finder cancelButton() => inSheet(find.widgetWithText(OutlinedButton, 'Cancel'));
Finder finalizeButton() =>
    inSheet(find.widgetWithText(FilledButton, 'Finalize'));

List<String> sheetMoney(WidgetTester tester) => [
  for (final element in inSheet(find.byType(Text)).evaluate())
    if (((element.widget as Text).data ?? '').startsWith('\$'))
      (element.widget as Text).data!,
];

/// Both actions are on screen, between the side insets and receive taps.
void expectActionsUsable(WidgetTester tester, Display display) {
  final usable = Rect.fromLTRB(
    display.inset.left,
    display.inset.top,
    display.size.width - display.inset.right,
    display.size.height,
  );
  for (final action in [cancelButton(), finalizeButton()]) {
    expect(action, findsOneWidget);
    expect(action.hitTestable(), findsOneWidget);
    final rect = tester.getRect(action);
    expect(
      rect.left >= usable.left - 0.5 &&
          rect.right <= usable.right + 0.5 &&
          rect.top >= usable.top - 0.5 &&
          rect.bottom <= usable.bottom + 0.5,
      isTrue,
      reason: 'action $rect leaves the usable area $usable on ${display.name}',
    );
    expect(rect.height, greaterThanOrEqualTo(40));
    expect(rect.width, greaterThanOrEqualTo(64));
  }
}

/// Drags the sheet content until [row] is fully inside the scroll viewport.
Future<void> scrollToRow(WidgetTester tester, Finder row) async {
  final scrollable = inSheet(find.byType(Scrollable));
  expect(scrollable, findsOneWidget, reason: 'settlement rows must scroll');
  Rect viewport() => tester.getRect(scrollable);
  bool visible() {
    final rect = tester.getRect(row);
    return rect.top >= viewport().top - 0.5 &&
        rect.bottom <= viewport().bottom + 0.5;
  }

  for (var drags = 0; drags < 400 && !visible(); drags++) {
    final direction = tester.getRect(row).top < viewport().top ? 1.0 : -1.0;
    final step = (viewport().height / 3).clamp(8.0, 120.0);
    // A real finger drag: the first move only passes the touch slop.
    final gesture = await tester.startGesture(viewport().center);
    await gesture.moveBy(Offset(0, direction * 20));
    await gesture.moveBy(Offset(0, direction * step));
    await gesture.up();
    await tester.pumpAndSettle();
  }
  await tester.pumpAndSettle();
  expect(visible(), isTrue, reason: 'row could not be scrolled into view');
}

// ---------------------------------------------------------------------------
// Real Tab detail fixture for the confirmation behaviour.

const backendTabId = 7;
const tabToken = 'synthetic-tab';

class RecordingApi extends ApiService {
  RecordingApi() : this._(<http.Request>[]);

  RecordingApi._(this.finalizeRequests)
    : super(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' &&
              path == '/api/tabs/$backendTabId/finalize') {
            finalizeRequests.add(request);
            return http.Response(
              jsonEncode({
                'settlements': [
                  {
                    'id': 1,
                    'tab_id': backendTabId,
                    'person_name': 'Alex',
                    'amount': 1,
                    'paid': false,
                  },
                ],
              }),
              200,
            );
          }
          if (request.method != 'GET') return http.Response('{}', 503);
          if (path == '/api/tabs/$backendTabId/members') {
            return http.Response('[]', 200);
          }
          if (path == '/api/tabs/$backendTabId') {
            return http.Response(
              jsonEncode({
                'bills': [
                  {
                    'id': 1,
                    'name': 'Synthetic dinner',
                    'currency_code': 'USD',
                    'subtotal': 1,
                    'tax': 0,
                    'tip_amount': 0,
                    'total': 1,
                    'usd_total': 1,
                    'participants': [
                      {'name': 'Alex'},
                    ],
                    'person_shares': [
                      {'id': 1, 'person_name': 'Alex', 'total': 1},
                    ],
                  },
                ],
                'total_amount': 1,
                'net_balance_status': 'available',
              }),
              200,
            );
          }
          return http.Response('{}', 503);
        }),
      );

  final List<http.Request> finalizeRequests;
  final readCompleted = Completer<void>();
  final finalized = Completer<void>();

  @override
  Future<List<TabMemberResponse>> getTabMembers(
    int tabId,
    String accessToken,
  ) async {
    try {
      return await super.getTabMembers(tabId, accessToken);
    } finally {
      if (!readCompleted.isCompleted) readCompleted.complete();
    }
  }

  @override
  Future<List<SettlementResponse>> finalizeTab(
    int tabId,
    String accessToken, {
    String? memberToken,
  }) async {
    try {
      return await super.finalizeTab(
        tabId,
        accessToken,
        memberToken: memberToken,
      );
    } finally {
      if (!finalized.isCompleted) finalized.complete();
    }
  }
}

Future<void> waitFor(WidgetTester tester, Future<void> future) async {
  await tester.runAsync(() => future.timeout(const Duration(seconds: 10)));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

Finder screenFinalize() =>
    find.widgetWithText(FloatingActionButton, 'Finalize');

/// Opens Tab detail for a synced, unfinalized tab and taps its Finalize action.
Future<({Harness h, RecordingApi api, int tabId})> openFromTabDetail(
  WidgetTester tester,
) async {
  useDisplay(tester, sePortrait);
  final h = Harness();
  addTearDown(h.db.close);
  final api = RecordingApi();
  final tabs = TabManager.withDependencies(
    database: h.db,
    receipts: h.owner,
    api: api,
  );
  addTearDown(tabs.dispose);
  final id =
      (await tester.runAsync(
        () => h.db.insertTab(
          const TabsCompanion(
            name: Value('Trip'),
            backendId: Value(backendTabId),
            accessToken: Value(tabToken),
          ),
        ),
      ))!;
  final tab = (await tester.runAsync(() => tabs.getTabById(id)))!;
  // Half scale approximates real glyph widths for the screen behind the sheet.
  await tester.pumpWidget(
    scaled(
      0.5,
      TabDetailScreen(
        tab: tab,
        tabManager: tabs,
        billsManager: h.owner,
        apiService: api,
        database: h.db,
      ),
    ),
  );
  await waitFor(tester, api.readCompleted.future);
  expect(screenFinalize(), findsOneWidget);
  await tester.tap(screenFinalize());
  await tester.pumpAndSettle();
  expect(inSheet(find.text('Finalize Tab')), findsOneWidget);
  expect(api.finalizeRequests, isEmpty);
  return (h: h, api: api, tabId: id);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Finalize confirmation', () {
    for (final display in displays) {
      for (final textScale in textScales) {
        testWidgets('fits ${display.name} at text scale $textScale', (
          tester,
        ) async {
          final result = await openSheet(tester, display, textScale);
          expect(tester.takeException(), isNull);

          // Money is unchanged: every person once, largest first.
          expect(sheetMoney(tester), expectedMoney);
          for (final label in personTotals.keys) {
            expect(inSheet(find.text(label)), findsOneWidget);
          }
          expectActionsUsable(tester, display);

          final sheet = tester.getRect(find.byType(BottomSheet));
          expect(sheet.top, greaterThanOrEqualTo(display.inset.top - 0.5));
          expect(sheet.bottom, lessThanOrEqualTo(display.size.height + 0.5));

          for (final amount in expectedMoney) {
            final row = inSheet(find.text(amount));
            expect(row, findsOneWidget);
            await scrollToRow(tester, row);
            expect(row.hitTestable(), findsOneWidget);
            final rect = tester.getRect(row);
            expect(
              rect.bottom,
              lessThanOrEqualTo(tester.getRect(finalizeButton()).top + 0.5),
              reason: '$amount is hidden behind the actions',
            );
            expect(rect.left, greaterThanOrEqualTo(display.inset.left - 0.5));
            expect(
              rect.right,
              lessThanOrEqualTo(display.size.width - display.inset.right + 0.5),
            );
            // The actions stay pinned while the rows move.
            expectActionsUsable(tester, display);
          }
          expect(tester.takeException(), isNull);
          expect(result.closed, isFalse);
        });
      }
    }

    testWidgets('a short preview keeps its compact height', (tester) async {
      await openSheet(
        tester,
        const Display('402x874 portrait', Size(402, 874)),
        0.5,
        totals: const {'Alex · member #1': 12.5, 'Sam · member #2': 7.25},
      );
      expect(tester.takeException(), isNull);
      expect(sheetMoney(tester), ['\$12.50', '\$7.25']);
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.bottom, 874);
      expect(sheet.height, lessThan(874 * 0.7));
      for (final amount in ['\$12.50', '\$7.25']) {
        expect(inSheet(find.text(amount)).hitTestable(), findsOneWidget);
      }
    });

    // Half scale approximates real glyph metrics in the test font. This is the
    // reported case: a few people on the shortest supported display.
    testWidgets('three people fit 320x568 without scrolling', (tester) async {
      const totals = <String, double>{
        'Alex · member #1': 41.5,
        'Sam · member #2': 27.25,
        'Jordan · receipt 3 #2': 9,
      };
      await openSheet(tester, sePortrait, 0.5, totals: totals);
      expect(tester.takeException(), isNull);
      expect(sheetMoney(tester), ['\$41.50', '\$27.25', '\$9.00']);
      for (final amount in sheetMoney(tester)) {
        expect(inSheet(find.text(amount)).hitTestable(), findsOneWidget);
      }
      expectActionsUsable(tester, sePortrait);
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.top, greaterThanOrEqualTo(sePortrait.inset.top));
      expect(sheet.bottom, 568);
    });

    testWidgets('a long preview stays within 70% of a tall display', (
      tester,
    ) async {
      await openSheet(
        tester,
        const Display('402x874 portrait', Size(402, 874)),
        1,
      );
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.height, closeTo(874 * 0.7, 0.5));
      expectActionsUsable(
        tester,
        const Display('402x874 portrait', Size(402, 874)),
      );
    });

    testWidgets('Finalize returns true after scrolling to the last row', (
      tester,
    ) async {
      final result = await openSheet(tester, sePortrait, 2);
      await scrollToRow(tester, inSheet(find.text(expectedMoney.last)));
      expect(result.closed, isFalse);
      await tester.tap(finalizeButton());
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(result.closed, isTrue);
      expect(result.value, isTrue);
    });

    testWidgets('Cancel returns false and dismissal returns null', (
      tester,
    ) async {
      final cancelled = await openSheet(tester, sePortrait, 2);
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(cancelled.closed, isTrue);
      expect(cancelled.value, isFalse);

      final dismissed = await openSheet(tester, sePortrait, 1);
      await tester.tapAt(const Offset(160, 30));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(dismissed.closed, isTrue);
      expect(dismissed.value, isNull);
    });

    testWidgets('Tab detail finalizes once with the same tab and token', (
      tester,
    ) async {
      final f = await openFromTabDetail(tester);
      expectActionsUsable(tester, sePortrait);

      await tester.tap(finalizeButton());
      await tester.pump();
      await waitFor(tester, f.api.finalized.future);

      expect(find.byType(BottomSheet), findsNothing);
      expect(f.api.finalizeRequests, hasLength(1));
      final request = f.api.finalizeRequests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/tabs/$backendTabId/finalize');
      expect(request.headers['Authorization'], 'Bearer $tabToken');
      expect(request.headers.containsKey('X-Member-Token'), isFalse);
      expect(request.body, isEmpty);
      final stored = (await tester.runAsync(() => f.h.db.getTabById(f.tabId)))!;
      expect(stored.finalized, isTrue);
      expect(screenFinalize(), findsNothing);
    });

    testWidgets('Tab detail never finalizes on Cancel or dismissal', (
      tester,
    ) async {
      final f = await openFromTabDetail(tester);
      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(screenFinalize());
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Finalize Tab')), findsOneWidget);
      await tester.tapAt(const Offset(160, 30));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(f.api.finalizeRequests, isEmpty);
      final stored = (await tester.runAsync(() => f.h.db.getTabById(f.tabId)))!;
      expect(stored.finalized, isFalse);
      expect(screenFinalize(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
