import 'dart:async';
import 'dart:convert';

import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness;

Map<String, dynamic> remoteReceipt(int id) => {
  'id': id,
  'name': 'Synthetic receipt $id',
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
    {'id': id, 'person_name': 'Alex', 'total': 1},
  ],
};

class FailingHistoryDatabase extends AppDatabase {
  FailingHistoryDatabase() : super.forTesting(NativeDatabase.memory());
  bool failRead = false;

  @override
  Future<List<RecentBill>> getRecentBills() {
    if (failRead) throw StateError('synthetic private read error');
    return super.getRecentBills();
  }
}

class CompletionWitnessApi extends ApiService {
  CompletionWitnessApi({required http.Client client})
    : super(baseUrl: 'https://synthetic.invalid', client: client);

  Completer<void> readCompleted = Completer<void>();

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
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('thirty remote receipts retain every returned local ID', () async {
    final h = Harness();
    addTearDown(h.db.close);
    final ids = await h.owner.importRemoteTabBills(7, [
      for (var i = 1; i <= 30; i++) remoteReceipt(i),
    ]);
    expect(ids.toSet(), hasLength(30));
    expect((await h.db.getRecentBills()).map((b) => b.id).toSet(), ids.toSet());
    expect(h.requests, isEmpty);
  });

  test(
    'thirty one remote receipts fail atomically without dangling IDs',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      await expectLater(
        h.owner.importRemoteTabBills(7, [
          for (var i = 1; i <= 31; i++) remoteReceipt(i),
        ]),
        throwsA(isA<StateError>()),
      );
      expect(await h.db.getRecentBills(), isEmpty);
    },
  );

  for (final protected in ['pending', 'referenced']) {
    test('$protected history survives a failed multi-receipt import', () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final ids = <int>[];
      for (var i = 0; i < 29; i++) {
        final saved = await h.save('protected-$i');
        ids.add(saved.localId);
        if (protected == 'referenced') {
          await h.db.checkpointReceipt(
            saved.localId,
            const RecentBillsCompanion(publicationState: Value('published')),
          );
        }
      }
      final tab = await h.tab();
      final references = protected == 'referenced' ? ids.join(',') : '';
      await h.db.updateTab(tab, TabsCompanion(billIds: Value(references)));
      final before =
          (await h.db.getRecentBills()).map((b) => b.toJson()).toList();
      await expectLater(
        h.owner.importRemoteTabBills(7, [
          remoteReceipt(100),
          remoteReceipt(101),
        ]),
        throwsA(isA<StateError>()),
      );
      expect(
        (await h.db.getRecentBills()).map((b) => b.toJson()).toList(),
        before,
      );
      expect((await h.db.getTabById(tab))!.billIds, references);
    });
  }

  test(
    'a later existing import target cannot be evicted by an earlier new row',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final old = await h.owner.importRemoteTabBills(7, [remoteReceipt(100)]);
      for (var i = 1; i < 30; i++) {
        await h.db.saveBill(
          participants: [],
          personShares: {},
          items: [],
          subtotal: 1,
          tax: 0,
          tipAmount: 0,
          total: 1,
          shareUrl: 'https://billington.app/b/${1000 + i}?t=synthetic',
        );
      }
      final ids = await h.owner.importRemoteTabBills(7, [
        remoteReceipt(101),
        remoteReceipt(100),
      ]);
      expect(ids.last, old.single);
      expect(await h.db.getBillById(old.single), isNotNull);
      expect(await h.db.getRecentBills(), hasLength(30));
    },
  );

  test(
    'malformed later receipt rolls back earlier refreshed content',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final ids = await h.owner.importRemoteTabBills(7, [remoteReceipt(1)]);
      final before = (await h.db.getBillById(ids.single))!.toJson();
      await expectLater(
        h.owner.importRemoteTabBills(7, [
          {...remoteReceipt(1), 'name': 'Must roll back'},
          {...remoteReceipt(2), 'total': 'not a number'},
        ]),
        throwsA(anything),
      );
      expect((await h.db.getBillById(ids.single))!.toJson(), before);
    },
  );

  testWidgets('local history read error clears loading and retry recovers', (
    tester,
  ) async {
    final db = FailingHistoryDatabase();
    final h = Harness(database: db);
    final tabs = TabManager.withDependencies(database: db, receipts: h.owner);
    addTearDown(tabs.dispose);
    addTearDown(db.close);
    final id =
        (await tester.runAsync(
          () => db.insertTab(
            const TabsCompanion(name: Value('Synthetic local trip')),
          ),
        ))!;
    final tab = (await tester.runAsync(() => tabs.getTabById(id)))!;
    db.failRead = true;
    await tester.pumpWidget(
      MaterialApp(
        home: TabDetailScreen(
          tab: tab,
          tabManager: tabs,
          billsManager: h.owner,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry current history'), findsOneWidget);
    expect(find.textContaining('synthetic private'), findsNothing);
    db.failRead = false;
    await tester.tap(find.text('Retry current history'));
    await tester.pumpAndSettle();
    expect(find.text('Retry current history'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('tab reference checkpoint failure rolls back the entire import', () async {
    final h = Harness();
    addTearDown(h.db.close);
    final tab = await h.tab();
    await h.db.customStatement(
      "CREATE TRIGGER reject_import BEFORE UPDATE OF bill_ids ON tabs BEGIN SELECT RAISE(ABORT, 'synthetic checkpoint'); END",
    );
    await expectLater(
      h.owner.importRemoteTabBills(7, [remoteReceipt(1)], localTabId: tab),
      throwsA(anything),
    );
    expect(await h.db.getRecentBills(), isEmpty);
    expect((await h.db.getTabById(tab))!.billIds, isEmpty);
  });

  test('invalid remote IDs never become a partial receipt list', () async {
    final h = Harness();
    addTearDown(h.db.close);
    for (final invalid in [null, 0, 1.5, '2', 1]) {
      await expectLater(
        h.owner.importRemoteTabBills(7, [
          remoteReceipt(1),
          {...remoteReceipt(2), 'id': invalid},
        ]),
        throwsA(isA<FormatException>()),
      );
      expect(await h.db.getRecentBills(), isEmpty);
    }
  });

  testWidgets(
    'full remote history offers retry without partial person balances',
    (tester) async {
      final h = Harness();
      addTearDown(h.db.close);
      final tabs = TabManager.withDependencies(
        database: h.db,
        receipts: h.owner,
      );
      addTearDown(tabs.dispose);
      final id =
          (await tester.runAsync(
            () => h.db.insertTab(
              const TabsCompanion(
                name: Value('Synthetic shared trip'),
                backendId: Value(7),
                accessToken: Value('synthetic-tab'),
              ),
            ),
          ))!;
      final tab = (await tester.runAsync(() => tabs.getTabById(id)))!;
      var count = 31;
      final api = CompletionWitnessApi(
        client: MockClient(
          (request) async =>
              request.url.path.endsWith('/members')
                  ? http.Response('[]', 200)
                  : http.Response(
                    jsonEncode({
                      'bills': [
                        for (var i = 1; i <= count; i++) remoteReceipt(i),
                      ],
                      'total_amount': count,
                      'net_balance_status': 'available',
                    }),
                    200,
                  ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TabDetailScreen(
            tab: tab,
            tabManager: tabs,
            billsManager: h.owner,
            apiService: api,
            database: h.db,
          ),
        ),
      );
      await tester.runAsync(
        () => api.readCompleted.future.timeout(const Duration(seconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry current history'), findsOneWidget);
      expect(find.textContaining('Person Totals'), findsNothing);
      expect(await tester.runAsync(h.db.getRecentBills), isEmpty);
      expect(
        (await tester.runAsync(() => h.db.getTabById(id)))!.billIds,
        isEmpty,
      );
      expect(find.text('Finalize'), findsNothing);
      count = 30;
      api.readCompleted = Completer<void>();
      await tester.tap(find.text('Retry current history'));
      await tester.runAsync(
        () => api.readCompleted.future.timeout(const Duration(seconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry current history'), findsNothing);
      expect(await tester.runAsync(h.db.getRecentBills), hasLength(30));
      final current = (await tester.runAsync(() => h.db.getTabById(id)))!;
      expect(current.billIds.split(','), hasLength(30));
      expect(tester.takeException(), isNull);
    },
  );
}
