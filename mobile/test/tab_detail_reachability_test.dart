import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/config/theme.dart';
import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness;

const _displays = [
  (name: 'iPhone SE', size: Size(320, 568), top: 20.0, bottom: 0.0),
  (name: 'iPhone 17e', size: Size(390, 844), top: 47.0, bottom: 34.0),
  (name: 'large iPhone', size: Size(440, 956), top: 62.0, bottom: 34.0),
];

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

class _Fixture {
  final h = Harness();
  late final tabs = TabManager.withDependencies(
    database: h.db,
    receipts: h.owner,
  );
  final ids = <int>[];
  final routes = _Routes();

  Future<void> show(
    WidgetTester tester,
    int displayIndex,
    int bodySize, {
    int bills = 4,
    String name = 'Trip',
  }) async {
    addTearDown(tabs.dispose);
    addTearDown(h.owner.dispose);
    addTearDown(h.db.close);
    final id =
        (await tester.runAsync(() async {
          for (var i = 0; i < bills; i++) {
            ids.add((await h.save('L21-row-$i')).localId);
          }
          return h.db.insertTab(
            TabsCompanion(name: Value(name), billIds: Value(ids.join(','))),
          );
        }))!;
    final tab = (await tester.runAsync(() => tabs.getTabById(id)))!;
    final display = _displays[displayIndex];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = display.size;
    tester.view.padding = FakeViewPadding(
      top: display.top,
      bottom: display.bottom,
    );
    tester.view.viewPadding = FakeViewPadding(
      top: display.top,
      bottom: display.bottom,
    );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.iOS),
        navigatorObservers: [routes],
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(bodySize / 17)),
              child: child!,
            ),
        home: TabDetailScreen(
          tab: tab,
          tabManager: tabs,
          billsManager: h.owner,
          apiService: h.api,
          database: h.db,
        ),
      ),
    );
    await tester.runAsync(() => tabs.getTabById(id));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

Future<void> _dragAboveButton(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  final button = find.byType(FloatingActionButton);
  bool clear() {
    if (target.evaluate().isEmpty) return false;
    final row = tester.getRect(target);
    return row.bottom <= tester.getRect(button).top - 8 &&
        row.bottom > tester.getRect(scrollable).top + 8;
  }

  for (var drags = 0; drags < 400 && !clear(); drags++) {
    final viewport = tester.getRect(scrollable);
    final gesture = await tester.startGesture(
      Offset(viewport.left + 10, viewport.center.dy),
    );
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -60));
    await gesture.up();
    await tester.pumpAndSettle();
  }
  expect(
    clear(),
    isTrue,
    reason:
        'row ${target.evaluate().isEmpty ? null : tester.getRect(target)}, button ${tester.getRect(button)}',
  );
  expect(tester.takeException(), isNull);
}

Finder _person(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label?.startsWith(prefix) ?? false),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (var displayIndex = 0; displayIndex < _displays.length; displayIndex++) {
    final display = _displays[displayIndex];
    if (displayIndex < 2) {
      for (final bodySize in [17, 53]) {
        testWidgets(
          'Tab detail last rows clear Add Receipt ${display.name} iOS body $bodySize',
          (tester) async {
            final f = _Fixture();
            await f.show(tester, displayIndex, bodySize);
            final lastPerson = _person('Birthday · receipt ${f.ids.last} #2:');
            await _dragAboveButton(tester, lastPerson);
            final amount = find.descendant(
              of: lastPerson,
              matching: find.text(r'$0.00'),
            );
            expect(amount.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(amount).top,
              greaterThanOrEqualTo(
                tester.getRect(find.byType(Scrollable).first).top,
              ),
            );
            expect(tester.widget<Text>(amount).maxLines, isNull);
            expect(tester.widget<Text>(amount).overflow, isNull);
            expect(tester.widget<Text>(amount).style!.fontSize, 16);
            expect(
              find.ancestor(of: amount, matching: find.byType(FittedBox)),
              findsNothing,
            );
            await tester.tap(amount);
            await tester.pumpAndSettle();
            expect(
              f.routes.pushed,
              hasLength(1),
              reason: 'the tap must not hit Add Receipt',
            );

            final card = find.byKey(ValueKey('bill_${f.ids.last}'));
            final receiptMoney = find.descendant(
              of: card,
              matching: find.text(r'$31.25'),
            );
            await _dragAboveButton(tester, receiptMoney);
            expect(receiptMoney.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(receiptMoney).top,
              greaterThanOrEqualTo(
                tester.getRect(find.byType(Scrollable).first).top,
              ),
            );
            expect(tester.widget<Text>(receiptMoney).maxLines, isNull);
            expect(tester.widget<Text>(receiptMoney).overflow, isNull);
            expect(tester.widget<Text>(receiptMoney).style!.fontSize, 15);
            expect(
              find.ancestor(of: receiptMoney, matching: find.byType(FittedBox)),
              findsNothing,
            );
            await tester.tap(receiptMoney);
            expect(f.routes.pushed, hasLength(2));
            final route = f.routes.pushed.last as MaterialPageRoute;
            expect(
              route.builder(tester.element(find.byType(TabDetailScreen))),
              isA<BillDetailsScreen>(),
            );
            // Validate the tap/destination without rendering an unrelated screen.
            route.navigator!.removeRoute(route);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Add Receipt'), findsOneWidget);
          },
        );
      }
    }

    testWidgets('Tab detail default rectangles match main ${display.name}', (
      tester,
    ) async {
      final f = _Fixture();
      await f.show(tester, displayIndex, 17, bills: 1);
      final rectangles = <String, List<double>>{};
      void record(String name, Finder finder) {
        final rect = tester.getRect(finder);
        final position =
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
        rectangles[name] =
            [
              rect.left,
              rect.top + position.pixels,
              rect.width,
              rect.height,
            ].map((v) => (v * 1000).roundToDouble() / 1000).toList();
      }

      record('heading', find.text('Per Person'));
      for (final label in [
        'Alex · receipt 1 #1:',
        'Birthday · receipt 1 #2:',
      ]) {
        final row = _person(label);
        record(label, row);
        final texts = find.descendant(of: row, matching: find.byType(Text));
        for (var i = 0; i < texts.evaluate().length; i++) {
          record('$label text $i', texts.at(i));
        }
        record(
          '$label avatar',
          find.descendant(of: row, matching: find.byType(CircleAvatar)),
        );
      }
      final card = find.byKey(const ValueKey('bill_1'));
      if (card.evaluate().isEmpty) {
        await tester.dragUntilVisible(
          card,
          find.byType(Scrollable).first,
          const Offset(0, -60),
        );
      }
      record(
        'receipt',
        find.descendant(of: card, matching: find.byType(InkWell)),
      );
      final texts = find.descendant(of: card, matching: find.byType(Text));
      for (var i = 0; i < texts.evaluate().length; i++) {
        record('receipt text $i', texts.at(i));
      }
      // Captured on f13409d (main), with the same fixture and real drags.
      final baseline =
          jsonDecode(
                File(
                  'test/fixtures/tab_detail_default_rectangles.json',
                ).readAsStringSync(),
              )
              as List;
      expect(rectangles, baseline[displayIndex]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Tab detail empty state preserves the entered tab name', (
    tester,
  ) async {
    final f = _Fixture();
    await f.show(tester, 1, 17, bills: 0, name: 'NYC Trip');
    expect(
      find.text('Add bills from your recent history\nto track this NYC Trip'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
