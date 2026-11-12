import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/screens/quick_split/bill_entry/bill_entry_screen.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness;
import 'tab_import_capacity_test.dart' show CompletionWitnessApi, remoteReceipt;

class FinalizationFixture {
  FinalizationFixture({AppDatabase? database})
    : h = Harness(database: database) {
    api = CompletionWitnessApi(
      client: MockClient((request) async {
        requests.add(request);
        if (offline) return http.Response('{}', 503);
        final path = request.url.path;
        if (path.endsWith('/members/me') || path.endsWith('/join')) {
          return http.Response(
            jsonEncode({
              'member_id': 42,
              'tab_id': 7,
              'member_token': 'synthetic-member',
              'display_name': 'Member',
              'role': role,
            }),
            memberStatus,
          );
        }
        if (path.endsWith('/members')) {
          return http.Response(
            jsonEncode([
              {'id': 42, 'display_name': 'Member', 'role': role},
            ]),
            200,
          );
        }
        if (path.endsWith('/finalize')) finalized = true;
        if (path.endsWith('/settlements') || path.endsWith('/finalize')) {
          return http.Response(
            jsonEncode({
              'accounting_currency': 'USD',
              'identity_review_status': 'ready',
              'settlements': [
                {
                  'id': 93,
                  'tab_id': 7,
                  'person_name': 'Server settlement',
                  'amount': 12.34,
                  'paid': true,
                },
              ],
            }),
            settlementStatus,
          );
        }
        expect(path, '/api/tabs/7');
        if (tabStatus != 200) return http.Response('{}', tabStatus);
        return http.Response(
          jsonEncode({
            'name': 'Shared trip',
            'finalized': finalized,
            'bills': malformedBills ? null : [remoteReceipt(11)],
            'total_amount': 1,
            'net_balance_status': 'available',
          }),
          200,
        );
      }),
    );
    tabs = TabManager.withDependencies(
      database: h.db,
      receipts: h.owner,
      api: api,
    );
  }

  final Harness h;
  late final CompletionWitnessApi api;
  late final TabManager tabs;
  final requests = <http.Request>[];
  Object? finalized = false;
  bool offline = false;
  bool malformedBills = false;
  int memberStatus = 200;
  int settlementStatus = 200;
  int tabStatus = 200;
  String role = 'member';

  Future<int> seed() => h.db.insertTab(
    TabsCompanion(
      name: const Value('Shared trip'),
      backendId: const Value(7),
      accessToken: const Value('synthetic-destination'),
      shareUrl: const Value(
        'https://billington.app/t/7?t=synthetic-destination',
      ),
      memberToken: const Value('synthetic-member'),
      memberId: const Value(42),
      role: Value(role),
      isRemote: Value(role != 'creator'),
    ),
  );

  Future<void> show(WidgetTester tester, int id) async {
    final tab = (await tester.runAsync(() => tabs.getTabById(id)))!;
    api.readCompleted = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: TabDetailScreen(
          key: UniqueKey(),
          tab: tab,
          tabManager: tabs,
          billsManager: h.owner,
          apiService: api,
          database: h.db,
        ),
      ),
    );
    await finishLoad(tester);
  }

  Future<void> finishLoad(WidgetTester tester) async {
    await tester.runAsync(
      () => api.readCompleted.future.timeout(const Duration(seconds: 10)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> refresh(WidgetTester tester) async {
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await tester.runAsync(refresh.onRefresh);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> expectClosed(WidgetTester tester, int id) async {
    expect(
      (await tester.runAsync(() => h.db.getTabById(id)))!.finalized,
      isTrue,
    );
    expect(find.text('Finalized'), findsOneWidget);
    expect(find.text('Add Receipt'), findsNothing);
    expect(find.text('Finalize'), findsNothing);
    expect(find.byTooltip('More tab actions'), findsNothing);
    expect(find.byType(BillEntryScreen), findsNothing);
  }

  Future<void> close() async {
    tabs.dispose();
    h.owner.dispose();
    await h.db.close();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'member refresh persists finalization and shows server settlements',
    (tester) async {
      final f = FinalizationFixture();
      addTearDown(f.close);
      final id = (await tester.runAsync(f.seed))!;
      await tester.runAsync(f.h.save);
      await f.show(tester, id);
      expect(find.text('Add Receipt'), findsOneWidget);
      final addReceipt =
          tester
              .widget<FloatingActionButton>(find.byType(FloatingActionButton))
              .onPressed!;
      final addExisting =
          tester
              .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>),
              )
              .onSelected!;
      f.finalized = true;
      await f.refresh(tester);
      await f.expectClosed(tester, id);
      expect(find.text('Server settlement · recorded row 93'), findsOneWidget);
      expect(find.text(r'$12.34'), findsOneWidget);
      expect(find.text('1/1 paid'), findsOneWidget);
      expect(
        f.requests.where((r) => r.url.path.endsWith('/settlements')),
        hasLength(1),
      );
      Future<void>? entryAction;
      await tester.runAsync(() async {
        entryAction = (addReceipt as Future<void> Function())();
        await f.tabs.getTabById(id);
      });
      await tester.pumpAndSettle();
      expect(find.byType(BillEntryScreen), findsNothing);
      await tester.runAsync(() => entryAction!);
      expect(find.textContaining('This tab is finalized'), findsOneWidget);
      await tester.runAsync(() async {
        addExisting('existing');
        await f.tabs.getTabById(id);
      });
      await tester.pumpAndSettle();
      expect(find.byType(BillEntryScreen), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(f.requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'stale open screen re-reads saved finalization before receipt entry',
    (tester) async {
      final f = FinalizationFixture();
      addTearDown(f.close);
      final id = (await tester.runAsync(f.seed))!;
      await f.show(tester, id);
      expect(find.text('Add Receipt'), findsOneWidget);
      // An invite link re-joined on another route and saved the server's state.
      await tester.runAsync(
        () => f.h.db.updateTab(id, const TabsCompanion(finalized: Value(true))),
      );
      await tester.tap(find.text('Add Receipt'));
      await tester.runAsync(() => f.tabs.getTabById(id));
      await tester.pumpAndSettle();
      expect(find.textContaining('This tab is finalized'), findsOneWidget);
      await f.expectClosed(tester, id);
    },
  );

  testWidgets('finalized member survives stale open reads and failed refresh', (
    tester,
  ) async {
    final f = FinalizationFixture()..finalized = true;
    addTearDown(f.close);
    final id = (await tester.runAsync(f.seed))!;
    await f.show(tester, id);
    await f.expectClosed(tester, id);
    f.finalized = false;
    await f.refresh(tester);
    await f.expectClosed(tester, id);
    f.offline = true;
    await f.refresh(tester);
    await f.expectClosed(tester, id);
    expect(
      find.textContaining('Recorded settlements are unavailable'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Server settlement · recorded row 93'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Server settlement · recorded row 93'), findsOneWidget);
  });

  testWidgets(
    'file reopen offline retains server finalization and refuses entry',
    (tester) async {
      final directory =
          (await tester.runAsync(
            () => Directory.systemTemp.createTemp('member-finalized-tab-'),
          ))!;
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/tab.sqlite');
      final first = FinalizationFixture(
        database: AppDatabase.forTesting(NativeDatabase(file)),
      )..finalized = true;
      final id = (await tester.runAsync(first.seed))!;
      try {
        await first.show(tester, id);
        await first.expectClosed(tester, id);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(first.close);
      }
      final reopened = FinalizationFixture(
        database: AppDatabase.forTesting(NativeDatabase(file)),
      )..offline = true;
      addTearDown(reopened.close);
      await reopened.show(tester, id);
      await reopened.expectClosed(tester, id);
      expect(
        find.textContaining('Recorded settlements are unavailable'),
        findsOneWidget,
      );
      expect(find.text('No recorded settlement rows.'), findsNothing);
    },
  );

  testWidgets('only literal server true closes an open member tab', (
    tester,
  ) async {
    final f = FinalizationFixture();
    addTearDown(f.close);
    final id = (await tester.runAsync(f.seed))!;
    for (final state in [false, null, 'true', 1]) {
      f.finalized = state;
      await f.show(tester, id);
      expect(
        (await tester.runAsync(() => f.h.db.getTabById(id)))!.finalized,
        isFalse,
      );
      expect(find.text('Finalized'), findsNothing);
      expect(find.text('Add Receipt'), findsOneWidget);
    }
    f.offline = true;
    await f.show(tester, id);
    expect(
      (await tester.runAsync(() => f.h.db.getTabById(id)))!.finalized,
      isFalse,
    );
    expect(
      f.requests.where((r) => r.url.path.endsWith('/settlements')),
      isEmpty,
    );
  });

  for (final failure in ['removed member', 'invalid receipts']) {
    testWidgets('server finalization survives $failure refresh failure', (
      tester,
    ) async {
      final f = FinalizationFixture()..finalized = true;
      addTearDown(f.close);
      final id = (await tester.runAsync(f.seed))!;
      if (failure == 'removed member') {
        f.memberStatus = 403;
      } else {
        f.malformedBills = true;
      }
      await f.show(tester, id);
      await f.expectClosed(tester, id);
      expect(find.text('Retry current history'), findsOneWidget);
      expect(find.text('Server settlement · recorded row 93'), findsOneWidget);
    });
  }

  for (final existing in [false, true]) {
    test(
      'joining finalized tab records server state for ${existing ? 'existing' : 'new'} member',
      () async {
        final f = FinalizationFixture()..finalized = true;
        addTearDown(f.close);
        final savedId = existing ? await f.seed() : null;
        final joined = await f.tabs.joinTab(
          'https://billington.app/t/7?t=synthetic-destination',
          'Member',
        );
        expect(joined, isNotNull);
        expect(joined!.isFinalized, isTrue);
        expect((await f.h.db.getTabById(joined.id!))!.finalized, isTrue);
        expect(await f.h.db.getAllTabs(), hasLength(1));
        if (existing) expect(joined.id, savedId);
        expect(
          f.requests.where((r) => r.url.path.endsWith('/join')),
          hasLength(existing ? 0 : 1),
        );
      },
    );
  }

  test('joining records only literal server true for new member', () async {
    final f = FinalizationFixture()..finalized = 'true';
    addTearDown(f.close);
    final joined = await f.tabs.joinTab(
      'https://billington.app/t/7?t=synthetic-destination',
      'Member',
    );
    expect(joined!.isFinalized, isFalse);
    expect((await f.h.db.getTabById(joined.id!))!.finalized, isFalse);
  });

  test('re-joining a saved tab survives a failed tab read', () async {
    final f = FinalizationFixture()..tabStatus = 503;
    addTearDown(f.close);
    final savedId = await f.seed();
    final joined = await f.tabs.joinTab(
      'https://billington.app/t/7?t=synthetic-destination',
      'Member',
    );
    expect(joined!.id, savedId);
    expect(joined.isFinalized, isFalse);
  });

  testWidgets(
    'open bill picker cannot attach after member refresh finalizes tab',
    (tester) async {
      final f = FinalizationFixture();
      addTearDown(f.close);
      final id = (await tester.runAsync(f.seed))!;
      final saved = (await tester.runAsync(f.h.save))!;
      await f.show(tester, id);
      await tester.tap(find.byTooltip('More tab actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add existing bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Synthetic'));
      await tester.pump();
      f.finalized = true;
      await f.refresh(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add 1'));
      await tester.runAsync(() => f.tabs.getTabById(id));
      await f.finishLoad(tester);
      await f.expectClosed(tester, id);
      expect(find.textContaining('This tab is finalized'), findsOneWidget);
      expect(find.textContaining('Not every selected bill'), findsNothing);
      expect(
        (await tester.runAsync(
          () => f.h.db.getTabById(id),
        ))!.billIds.split(','),
        isNot(contains('${saved.localId}')),
      );
      expect(f.h.attachments, 0);
      expect(
        (await tester.runAsync(
          () => f.h.db.getBillById(saved.localId),
        ))!.intendedTabId,
        isNull,
      );
    },
  );

  testWidgets(
    'pending local save cannot attach after server finalization is persisted',
    (tester) async {
      final f = FinalizationFixture()..finalized = true;
      addTearDown(f.close);
      final id = (await tester.runAsync(f.seed))!;
      final saved = (await tester.runAsync(f.h.save))!;
      await tester.runAsync(
        () => f.h.db.checkpointReceipt(
          saved.localId,
          RecentBillsCompanion(
            intendedTabId: Value(id),
            attachmentState: const Value('pending'),
          ),
        ),
      );
      await f.show(tester, id);
      final resumed =
          (await tester.runAsync(
            () => f.h.owner.resumeReceipt(saved.localId),
          ))!;
      expect(resumed.attachment, AttachmentState.pending);
      expect(f.h.attachments, 0);
      await f.expectClosed(tester, id);
      expect(
        await tester.runAsync(() => f.tabs.addBillsToTab(id, [saved.localId])),
        isFalse,
      );
    },
  );

  testWidgets(
    'creator finalization still uses existing server finalize and settlement paths',
    (tester) async {
      final f = FinalizationFixture()..role = 'creator';
      addTearDown(f.close);
      final id = (await tester.runAsync(f.seed))!;
      await f.show(tester, id);
      expect(find.text('Finalize'), findsOneWidget);
      expect(await tester.runAsync(() => f.tabs.finalizeTab(id)), isTrue);
      await f.refresh(tester);
      await f.expectClosed(tester, id);
      expect(find.text(r'$12.34'), findsOneWidget);
      final finalize = f.requests.singleWhere(
        (r) => r.url.path.endsWith('/finalize'),
      );
      expect(finalize.method, 'POST');
      expect(finalize.headers['X-Member-Token'], 'synthetic-member');
    },
  );
}
