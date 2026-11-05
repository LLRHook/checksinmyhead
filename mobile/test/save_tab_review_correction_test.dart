import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness, alex, creationResponse, draft;

class PublishedReadBarrierDatabase extends AppDatabase {
  PublishedReadBarrierDatabase() : super.forTesting(NativeDatabase.memory());
  bool armed = false;
  final entered = Completer<void>(), release = Completer<void>();

  @override
  Future<RecentBill?> getBillById(int id) async {
    final row = await super.getBillById(id);
    if (armed &&
        !entered.isCompleted &&
        row?.publicationState == 'published' &&
        row?.intendedTabId == null) {
      entered.complete();
      await release.future;
    }
    return row;
  }
}

Future<bool> destinationStored(Harness h, int receipt, int tab) async {
  // A single watchdog bounds the rendezvous; this is not a latency measurement.
  final query = h.db.select(h.db.recentBills)
    ..where((row) => row.id.equals(receipt));
  return query
      .watchSingle()
      .firstWhere((row) => row.intendedTabId == tab)
      .then((_) => true)
      .timeout(const Duration(seconds: 2), onTimeout: () => false);
}

Future<({int first, int review, int last, int tab})> seedSelection(
  Harness h,
) async {
  h.onCreate =
      (request) async => http.Response(
        jsonEncode(
          creationResponse(jsonDecode(request.body), id: 18 + h.posts),
        ),
        201,
      );
  final first = await h.owner.saveReceipt(
    operationHandle: 'selection-first',
    receipt: draft().copyWith(billName: 'First receipt'),
  );
  final review = await h.db.saveBill(
    participants: [alex],
    personShares: {alex: 25},
    items: [
      BillItem(name: 'Raw history', price: 25, assignments: {alex: -1}),
    ],
    subtotal: 25,
    tax: 0,
    tipAmount: 0,
    total: 25,
    billName: 'Review receipt',
    skipDuplicateCheck: true,
  );
  final last = await h.owner.saveReceipt(
    operationHandle: 'selection-last',
    receipt: draft().copyWith(billName: 'Last receipt'),
  );
  return (
    first: first.localId,
    review: review,
    last: last.localId,
    tab: await h.tab(),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'standalone launch recovery without a tab retains one publication',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final saved = await h.save();
      h.replay = true;
      await h.owner.retryPendingUploads();
      final row = (await h.db.getBillById(saved.localId))!;
      expect(await h.db.getRecentBills(), hasLength(1));
      expect(row.publicationState, 'published');
      expect(row.intendedTabId, isNull);
      expect(row.attachmentState, 'none');
      expect(h.posts, 1);
      expect(h.attachments, 0);
      expect(h.keys.creates, 1);
    },
  );

  for (final lostResponse in [false, true]) {
    test(
      'launch recovery retains overlapping tab intent ${lostResponse ? 'after lost201 without automatic create retry' : 'and attaches once'}',
      () async {
        final h = Harness()..replay = false;
        addTearDown(h.db.close);
        final saved = await h.save();
        final tab = await h.tab();
        final entered = Completer<void>(), release = Completer<void>();
        h.replay = true;
        h.onCreate = (request) async {
          entered.complete();
          await release.future;
          if (lostResponse) throw const SocketException('synthetic lost201');
          return http.Response(
            jsonEncode(creationResponse(jsonDecode(request.body))),
            201,
          );
        };
        final launch = h.owner.retryPendingUploads();
        await entered.future;
        final addition = h.owner.resumeReceipt(
          saved.localId,
          intendedTabId: tab,
        );
        try {
          expect(
            await destinationStored(h, saved.localId, tab),
            isTrue,
            reason:
                'The new destination must be durable while publication is in flight',
          );
        } finally {
          release.complete();
          await launch;
          await addition;
        }
        final result = await addition;
        final row = (await h.db.getBillById(saved.localId))!;
        expect(row.intendedTabId, tab);
        expect(h.posts, 1);
        expect(h.keys.creates, 1);
        expect(await h.db.getRecentBills(), hasLength(1));
        expect(
          result.attachment,
          lostResponse ? AttachmentState.pending : AttachmentState.attached,
        );
        expect(h.attachments, lostResponse ? 0 : 1);
        if (lostResponse) {
          expect(row.publicationAttempted, true);
          expect(row.remoteBillId, isNull);
          h.onCreate = null;
          final recovered = await h.owner.resumeReceipt(saved.localId);
          expect(recovered.attachment, AttachmentState.attached);
          expect(h.posts, 2);
          expect(h.attachments, 1);
          expect(h.keys.creates, 1);
        }
      },
    );
  }

  test(
    'tab intent arriving after the publication read attaches without another create',
    () async {
      final db = PublishedReadBarrierDatabase();
      final h = Harness(database: db)..replay = false;
      addTearDown(db.close);
      final saved = await h.save();
      final tab = await h.tab();
      h.replay = true;
      db.armed = true;
      final launch = h.owner.retryPendingUploads();
      await db.entered.future;
      final addition = h.owner.resumeReceipt(saved.localId, intendedTabId: tab);
      try {
        expect(await destinationStored(h, saved.localId, tab), isTrue);
      } finally {
        db.release.complete();
        await launch;
        await addition;
      }
      expect((await addition).attachment, AttachmentState.attached);
      expect((await db.getTabById(tab))!.billIds, '${saved.localId}');
      expect(h.posts, 1);
      expect(h.attachments, 1);
      expect(h.keys.creates, 1);
    },
  );

  test(
    'one explicit tab request never automatically repeats a failed attachment',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final saved = await h.save();
      final tab = await h.tab();
      h.onAttach =
          (_) async =>
              throw const SocketException('synthetic attachment response lost');
      final result = await h.owner.resumeReceipt(
        saved.localId,
        intendedTabId: tab,
      );
      expect(result.attachment, AttachmentState.attempted);
      expect(result.failure, SaveFailure.attachmentUnknown);
      expect(h.posts, 1);
      expect(h.attachments, 1);
      expect((await h.db.getBillById(saved.localId))!.intendedTabId, tab);
    },
  );

  test(
    'overlapping destination conflict preserves the first durable trip',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final saved = await h.save();
      final firstTab = await h.tab(), secondTab = await h.tab();
      final entered = Completer<void>(), release = Completer<void>();
      h.replay = true;
      h.onCreate = (request) async {
        entered.complete();
        await release.future;
        return http.Response(
          jsonEncode(creationResponse(jsonDecode(request.body))),
          201,
        );
      };
      final launch = h.owner.retryPendingUploads();
      await entered.future;
      final first = h.owner.resumeReceipt(
        saved.localId,
        intendedTabId: firstTab,
      );
      try {
        expect(await destinationStored(h, saved.localId, firstTab), isTrue);
        final conflict = await h.owner.resumeReceipt(
          saved.localId,
          intendedTabId: secondTab,
        );
        expect(conflict.failure, SaveFailure.attachmentUnknown);
        expect(
          (await h.db.getBillById(saved.localId))!.intendedTabId,
          firstTab,
        );
      } finally {
        release.complete();
        await launch;
        await first;
      }
      expect((await first).attachment, AttachmentState.attached);
      expect((await first).failure, isNull);
      expect((await h.db.getTabById(firstTab))!.billIds, '${saved.localId}');
      expect((await h.db.getTabById(secondTab))!.billIds, isEmpty);
      expect(h.posts, 1);
      expect(h.attachments, 1);
    },
  );

  test(
    'tab selection preserves earlier additions and continues after raw-history and missing-row failures',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final ids = await seedSelection(h);
      final before = (await h.db.getBillById(ids.review))!.items;
      final tabs = TabManager.withDependencies(
        database: h.db,
        receipts: h.owner,
      );
      addTearDown(tabs.dispose);
      Object? escaped;
      bool? complete;
      try {
        complete = await tabs.addBillsToTab(ids.tab, [
          ids.first,
          ids.review,
          999999,
          ids.last,
        ]);
      } catch (error) {
        escaped = error;
      }
      expect(
        escaped,
        isNull,
        reason: 'A selected history row must not abort the whole action',
      );
      expect(complete, false);
      final local = (await h.db.getTabById(ids.tab))!;
      expect(local.billIds.split(',').map(int.parse), [ids.first, ids.last]);
      expect((await h.db.getBillById(ids.review))!.items, before);
      expect(h.posts, 2);
      expect(h.attachments, 2);
    },
  );

  testWidgets(
    'actual tab selector gives review feedback and retains successful additions',
    (tester) async {
      final h = Harness();
      addTearDown(h.db.close);
      final ids = await tester.runAsync(() => seedSelection(h));
      final tabs = TabManager.withDependencies(
        database: h.db,
        receipts: h.owner,
      );
      addTearDown(tabs.dispose);
      final tab = await tester.runAsync(() => tabs.getTabById(ids!.tab));
      final offlineRead = ApiService(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TabDetailScreen(
            tab: tab!,
            tabManager: tabs,
            billsManager: h.owner,
            apiService: offlineRead,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More tab actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add existing bill'));
      await tester.pumpAndSettle();
      for (final name in ['First receipt', 'Review receipt', 'Last receipt']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, name));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Add 3'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Review saved receipts'), findsOneWidget);
      final local = await tester.runAsync(() => h.db.getTabById(ids!.tab));
      expect(local!.billIds.split(',').map(int.parse), [ids!.first, ids.last]);
      expect(h.attachments, 2);
    },
  );
}
