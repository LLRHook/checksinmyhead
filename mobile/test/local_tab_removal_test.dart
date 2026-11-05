import 'dart:io';

import 'package:drift/native.dart';
import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/screens/tabs/tabs_screen.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness;

Future<({Harness h, TabManager tabs, int tab, int receipt})> seed({
  bool synced = false,
  bool finalized = false,
  AppDatabase? database,
}) async {
  final h = Harness(database: database)..replay = false;
  final receipt = await h.save('local-removal');
  final tab = await h.db.insertTab(
    TabsCompanion(
      name: const Value('Synthetic shared trip'),
      billIds: Value('${receipt.localId}'),
      backendId: Value(synced ? 7 : null),
      accessToken: Value(synced ? 'synthetic-shared' : null),
      finalized: Value(finalized),
    ),
  );
  final tabs = TabManager.withDependencies(database: h.db, receipts: h.owner);
  return (h: h, tabs: tabs, tab: tab, receipt: receipt.localId);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('local bill removal retains the saved receipt', () async {
    final f = await seed();
    addTearDown(f.tabs.dispose);
    addTearDown(f.h.db.close);
    expect(await f.tabs.removeBillFromTab(f.tab, f.receipt), isTrue);
    expect((await f.h.db.getTabById(f.tab))!.billIds, isEmpty);
    expect(await f.h.db.getBillById(f.receipt), isNotNull);
  });
  test(
    'synced local removal refuses to pretend to detach a shared bill',
    () async {
      final f = await seed(synced: true);
      addTearDown(f.tabs.dispose);
      addTearDown(f.h.db.close);
      await f.tabs.removeBillFromTab(f.tab, f.receipt);
      expect((await f.h.db.getTabById(f.tab))!.billIds, '${f.receipt}');
      expect(await f.h.db.getBillById(f.receipt), isNotNull);
    },
  );
  test('a rejected local tab delete keeps the real Drift row', () async {
    final f = await seed();
    addTearDown(f.tabs.dispose);
    addTearDown(f.h.db.close);
    await f.h.db.customStatement(
      "CREATE TRIGGER reject_remove BEFORE DELETE ON tabs BEGIN SELECT RAISE(ABORT, 'synthetic private failure'); END",
    );
    expect(await f.tabs.deleteTab(f.tab), isFalse);
    expect(await f.h.db.getTabById(f.tab), isNotNull);
    expect(await f.h.db.getBillById(f.receipt), isNotNull);
  });
  testWidgets('synced bill has no swipe removal affordance', (tester) async {
    final f = (await tester.runAsync(() => seed(synced: true)))!;
    addTearDown(f.tabs.dispose);
    addTearDown(f.h.db.close);
    final tab = await tester.runAsync(() => f.tabs.getTabById(f.tab));
    await tester.pumpWidget(
      MaterialApp(
        home: TabDetailScreen(
          tab: tab!,
          tabManager: f.tabs,
          billsManager: f.h.owner,
          apiService: ApiService(
            baseUrl: 'https://synthetic.invalid',
            client: MockClient((_) async => http.Response('{}', 503)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(ValueKey('bill_${f.receipt}'));
    expect(tester.widget<Dismissible>(card).direction, DismissDirection.none);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.contains('Swipe left to remove') ?? false),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'local tab removal preserves receipts and an independent local view',
    () async {
      final first = await seed(synced: true);
      final second = await seed(synced: true);
      addTearDown(first.tabs.dispose);
      addTearDown(first.h.db.close);
      addTearDown(second.tabs.dispose);
      addTearDown(second.h.db.close);
      final requests = first.h.requests.length;
      expect(await first.tabs.deleteTab(first.tab), isTrue);
      expect(await first.h.db.getTabById(first.tab), isNull);
      expect(await first.h.db.getBillById(first.receipt), isNotNull);
      expect((await second.tabs.getTabById(second.tab))!.billIds, [
        second.receipt,
      ]);
      expect(await second.h.db.getBillById(second.receipt), isNotNull);
      expect(
        first.h.requests.length,
        requests,
        reason: 'local removal sends no API request',
      );
      expect(
        await first.tabs.deleteTab(first.tab),
        isTrue,
        reason: 'already absent is complete',
      );
    },
  );
  test(
    'rejected bill-list write returns failure without altering history',
    () async {
      final f = await seed();
      addTearDown(f.tabs.dispose);
      addTearDown(f.h.db.close);
      await f.h.db.customStatement(
        "CREATE TRIGGER reject_list BEFORE UPDATE ON tabs BEGIN SELECT RAISE(ABORT, 'synthetic private write failure'); END",
      );
      expect(await f.tabs.removeBillFromTab(f.tab, f.receipt), isFalse);
      expect((await f.h.db.getTabById(f.tab))!.billIds, '${f.receipt}');
      expect(await f.h.db.getBillById(f.receipt), isNotNull);
    },
  );
  test('finalized local tabs refuse membership removal at the owner', () async {
    final f = await seed(finalized: true);
    addTearDown(f.tabs.dispose);
    addTearDown(f.h.db.close);
    expect(await f.tabs.removeBillFromTab(f.tab, f.receipt), isFalse);
    expect((await f.tabs.getTabById(f.tab))!.billIds, [f.receipt]);
  });
  testWidgets('cancel local tab removal makes no mutation', (tester) async {
    final f = (await tester.runAsync(seed))!;
    addTearDown(f.tabs.dispose);
    addTearDown(f.h.db.close);
    await tester.pumpWidget(MaterialApp(home: TabsScreen(tabManager: f.tabs)));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(ValueKey('tab_${f.tab}')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => f.h.db.getTabById(f.tab)), isNotNull);
    expect(find.byKey(ValueKey('tab_${f.tab}')), findsOneWidget);
    expect(find.textContaining('Removed "'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed tab removal keeps the visible card and gives finite feedback',
    (tester) async {
      final f = (await tester.runAsync(seed))!;
      addTearDown(f.tabs.dispose);
      addTearDown(f.h.db.close);
      await tester.runAsync(
        () => f.h.db.customStatement(
          "CREATE TRIGGER reject_tab BEFORE DELETE ON tabs BEGIN SELECT RAISE(ABORT, 'private error marker'); END",
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: TabsScreen(tabManager: f.tabs)),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(ValueKey('tab_${f.tab}')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Remove from this device'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('tab_${f.tab}')), findsOneWidget);
      expect(find.textContaining('Could not remove this tab'), findsOneWidget);
      expect(find.textContaining('Removed "'), findsNothing);
      expect(find.textContaining('private error marker'), findsNothing);
      expect(await tester.runAsync(() => f.h.db.getTabById(f.tab)), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'local tab removal wraps at narrow width and large text and keeps receipt',
    (tester) async {
      final f = (await tester.runAsync(seed))!;
      addTearDown(f.tabs.dispose);
      addTearDown(f.h.db.close);
      await tester.runAsync(
        () => f.h.db.updateTab(
          f.tab,
          const TabsCompanion(
            name: Value(
              'A very long synthetic dinner tab name for friends and family',
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
          home: TabsScreen(tabManager: f.tabs),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(ValueKey('tab_${f.tab}')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(
        FilledButton,
        'Remove from this device',
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('tab_${f.tab}')), findsNothing);
      expect(await tester.runAsync(() => f.h.db.getTabById(f.tab)), isNull);
      expect(
        await tester.runAsync(() => f.h.db.getBillById(f.receipt)),
        isNotNull,
      );
      expect(find.textContaining('from this device'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final failWrite in [false, true]) {
    testWidgets(
      'local bill cancel and confirmed removal acknowledge DB success ($failWrite)',
      (tester) async {
        final f = (await tester.runAsync(seed))!;
        addTearDown(f.tabs.dispose);
        addTearDown(f.h.db.close);
        if (failWrite) {
          await tester.runAsync(
            () => f.h.db.customStatement(
              "CREATE TRIGGER reject_local_bill BEFORE UPDATE ON tabs BEGIN SELECT RAISE(ABORT, 'private local error'); END",
            ),
          );
        }
        final tab = await tester.runAsync(() => f.tabs.getTabById(f.tab));
        await tester.pumpWidget(
          MaterialApp(
            home: TabDetailScreen(
              tab: tab!,
              tabManager: f.tabs,
              billsManager: f.h.owner,
              apiService: f.h.api,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('bill_${f.receipt}'));
        await tester.ensureVisible(card);
        await tester.drag(card, const Offset(-600, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(() => f.h.db.getTabById(f.tab)))!.billIds,
          '${f.receipt}',
        );
        await tester.drag(card, const Offset(-600, 0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Remove from local tab'),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('bill_${f.receipt}')),
          failWrite ? findsOneWidget : findsNothing,
        );
        expect(
          (await tester.runAsync(() => f.h.db.getTabById(f.tab)))!.billIds,
          failWrite ? '${f.receipt}' : '',
        );
        expect(
          await tester.runAsync(() => f.h.db.getBillById(f.receipt)),
          isNotNull,
        );
        expect(
          find.textContaining(
            failWrite ? 'Could not remove this bill' : 'Saved receipt kept',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'file-backed reopen preserves shared membership and only removes the local tab entry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'billington-local-removal-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/local.sqlite');
      late int tabId, receiptId;
      final first = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final f = await seed(synced: true, database: first);
        tabId = f.tab;
        receiptId = f.receipt;
        try {
          expect(await f.tabs.removeBillFromTab(tabId, receiptId), isFalse);
        } finally {
          f.tabs.dispose();
        }
      } finally {
        await first.close();
      }
      final second = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final h = Harness(database: second);
        final manager = TabManager.withDependencies(
          database: second,
          receipts: h.owner,
        );
        try {
          expect((await manager.getTabById(tabId))!.billIds, [receiptId]);
          expect(await second.getBillById(receiptId), isNotNull);
          expect(await manager.deleteTab(tabId), isTrue);
        } finally {
          manager.dispose();
        }
      } finally {
        await second.close();
      }
      final third = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(await third.getTabById(tabId), isNull);
        expect(await third.getBillById(receiptId), isNotNull);
      } finally {
        await third.close();
      }
    },
  );
}
