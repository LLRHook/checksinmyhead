import 'dart:convert';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'save_receipt_test.dart' show Harness;

void main() {
  test(
    'unknown identity conflict codes show the server message and preserve fallback',
    () async {
      var body = <String, dynamic>{
        'code': 'participants_locked_paid',
        'error': 'participants cannot be added after a share is paid',
      };
      var calls = 0;
      final api = ApiService(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient((request) async {
          calls++;
          return http.Response(jsonEncode(body), 409);
        }),
      );
      Future<void> add() async {
        await api.participantCommand(
          billId: '7',
          token: 'source',
          expectedRevision: 1,
          clientRef: 'new',
          label: 'Pat',
        );
      }

      await expectLater(
        add(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'participants_locked_paid')
              .having(
                (e) => e.message,
                'message',
                'participants cannot be added after a share is paid',
              ),
        ),
      );
      expect(calls, 1);
      body = {
        'code': 'future_conflict',
        'error': 'A specific future conflict.',
      };
      await expectLater(
        add(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'A specific future conflict.',
          ),
        ),
      );
      body = {
        'code': 'future_conflict',
        'error': {'unsafe': 'not text'},
      };
      await expectLater(
        add(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'State changed or needs review. Refresh and deliberately retry.',
          ),
        ),
      );
    },
  );

  test(
    'strict participant commands send independent source body proof only on attached rename or decision',
    () async {
      final requests = <http.Request>[];
      final api = ApiService(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"participant":{"participant_id":11,"bill_id":7,"client_ref":"r","label":"Alex","binding_state":"unbound"},"identity_revision":4}',
            200,
          );
        }),
      );
      await api.participantCommand(
        billId: '7',
        token: 'destination',
        tabId: '9',
        memberToken: 'actor',
        expectedRevision: 3,
        clientRef: 'new',
        label: 'Alex',
        billToken: 'source',
      );
      await api.participantCommand(
        billId: '7',
        token: 'independent-source',
        participantId: 11,
        expectedRevision: 3,
        label: 'Standalone rename',
        billToken: 'unused-source-field',
      );
      await api.participantCommand(
        billId: '7',
        token: 'destination',
        tabId: '9',
        memberToken: 'actor',
        expectedRevision: 3,
        participantId: 11,
        bindingRequest: true,
        billToken: 'source',
      );
      await api.participantCommand(
        billId: '7',
        token: 'destination',
        tabId: '9',
        memberToken: 'actor',
        expectedRevision: 3,
        participantId: 11,
        label: 'Renamed',
        billToken: 'source',
      );
      await api.participantCommand(
        billId: '7',
        token: 'destination',
        tabId: '9',
        memberToken: 'actor',
        expectedRevision: 3,
        participantId: 11,
        decision: 'reject',
        requestRevision: 3,
        memberId: 22,
        billToken: 'source',
      );
      expect(jsonDecode(requests[0].body), {
        'expected_revision': 3,
        'client_ref': 'new',
        'name': 'Alex',
      });
      expect(jsonDecode(requests[1].body), {
        'expected_revision': 3,
        'name': 'Standalone rename',
      });
      expect(requests[1].headers['Authorization'], 'Bearer independent-source');
      expect(jsonDecode(requests[2].body), {'expected_revision': 3});
      expect(jsonDecode(requests[3].body)['bill_token'], 'source');
      expect(jsonDecode(requests[4].body)['bill_token'], 'source');
    },
  );
  test(
    'settlement history retains raw legacy rows and review while denied unavailable malformed and cross-scope stay errors',
    () async {
      var code = 200;
      var body = {
        'settlements': [
          {'id': 11, 'tab_id': 9, 'person_name': '', 'amount': 2, 'paid': true},
          {
            'id': 12,
            'tab_id': 9,
            'person_name': '',
            'amount': 3,
            'paid': false,
          },
        ],
        'identity_review_status': 'legacy_identity_review_required',
        'accounting_currency': 'USD',
      };
      final api = ApiService(
        baseUrl: 'https://synthetic.invalid',
        client: MockClient((_) async => http.Response(jsonEncode(body), code)),
      );
      final history = await api.getSettlementHistory(9, 'destination');
      expect(history.reviewStatus, 'legacy_identity_review_required');
      expect(history.rows.map((r) => r.id), [11, 12]);
      expect(history.rows.map((r) => r.amount), [2, 3]);
      for (final denied in [403, 409, 503]) {
        code = denied;
        await expectLater(
          api.getSettlementHistory(9, 'destination'),
          throwsA(isA<ApiException>()),
        );
      }
      code = 200;
      body = {'settlements': []};
      await expectLater(
        api.getSettlementHistory(9, 'destination'),
        throwsA(isA<ApiException>()),
      );
      body = {
        'settlements': [
          {
            'id': 11,
            'tab_id': 8,
            'person_name': '',
            'amount': 2,
            'paid': false,
          },
        ],
        'identity_review_status': 'ready',
        'accounting_currency': 'USD',
      };
      await expectLater(
        api.getSettlementHistory(9, 'destination'),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'attempted version1 envelope never upgrades to wire2 after metadata mismatch',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final saved = await h.save();
      final before = (await h.db.getBillById(saved.localId))!;
      const frozen =
          ' { "name":"Frozen v1", "subtotal":1, "total":1, "currency_code":"USD", "participants":[{"name":"Alex"}], "items":[{"name":"Meal","price":1,"assignments":[{"person_name":"Alex","percentage":100}]}] }\n';
      final key = await h.keys.createIfAbsent(before.keyLocator!);
      final creates = h.keys.creates;
      await h.db.checkpointReceipt(
        saved.localId,
        const RecentBillsCompanion(
          creationSnapshot: Value(frozen),
          snapshotVersion: Value(1),
          creationWireVersion: Value(2),
          publicationAttempted: Value(true),
        ),
      );
      h.requests.clear();
      h.replay = true;
      final result = await h.owner.resumeReceipt(saved.localId);
      expect(result.failure, SaveFailure.snapshotReview);
      expect(h.posts, 0);
      expect(h.requests, isEmpty);
      final after = (await h.db.getBillById(saved.localId))!;
      expect(after.publicationState, 'blocked');
      expect(after.creationSnapshot, frozen);
      expect(after.keyLocator, before.keyLocator);
      expect(after.creationHandle, before.creationHandle);
      expect(after.snapshotVersion, 1);
      expect(after.creationWireVersion, 2);
      expect(
        (await h.keys.read(after.keyLocator!)).canonicalKey,
        key.canonicalKey,
      );
      expect(h.keys.creates, creates);
    },
  );

  Future<void> showHistory(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) respond, {
    bool cachedReceipt = false,
  }) async {
    final h = Harness();
    addTearDown(h.db.close);
    addTearDown(h.owner.dispose);
    final cachedId = cachedReceipt ? (await h.save()).localId : null;
    final api = ApiService(
      baseUrl: 'https://synthetic.invalid',
      client: MockClient(respond),
    );
    final tabs = TabManager.withDependencies(
      database: h.db,
      receipts: h.owner,
      api: api,
    );
    addTearDown(tabs.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TabDetailScreen(
          tab: AppTab(
            name: 'Recorded trip',
            createdAt: DateTime(2001),
            billIds: [if (cachedId != null) cachedId],
            backendId: 9,
            accessToken: 'destination',
            finalized: true,
          ),
          tabManager: tabs,
          billsManager: h.owner,
          apiService: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> rawHistory(String status) => {
    'settlements': [
      {'id': 11, 'tab_id': 9, 'person_name': '', 'amount': 2, 'paid': true},
      {'id': 12, 'tab_id': 9, 'person_name': '', 'amount': 3, 'paid': false},
    ],
    'identity_review_status': status,
    'accounting_currency': 'USD',
  };

  testWidgets(
    'settlement marker ACK then failed read retains raw rows and renders GET-only recovery without another PATCH',
    (tester) async {
      var reads = 0;
      final writes = <http.Request>[];
      await showHistory(tester, (request) async {
        if (request.method == 'PATCH') {
          writes.add(request);
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/members')) {
          return http.Response('[]', 200);
        }
        reads++;
        if (reads == 2) return http.Response('{}', 503);
        final history = rawHistory('legacy_identity_review_required');
        if (reads == 3) (history['settlements'] as List).last['paid'] = true;
        return http.Response(jsonEncode(history), 200);
      });
      await tester.tap(find.text('Unnamed · recorded row 12'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Marker saved for recorded row 12'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Recorded settlements are unavailable'),
        findsOneWidget,
      );
      expect(find.text('Unnamed · recorded row 11'), findsOneWidget);
      expect(find.text('Unnamed · recorded row 12'), findsOneWidget);
      expect(reads, 2);
      expect(writes, hasLength(1));
      await tester.ensureVisible(find.text('Retry current settlement status'));
      await tester.tap(find.text('Retry current settlement status'));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(writes, hasLength(1));
      expect(writes.single.url.path, '/api/tabs/9/settlements/12');
      expect(
        find.textContaining('Marker saved for recorded row 12'),
        findsNothing,
      );
      expect(find.text('Retry current settlement status'), findsNothing);
      expect(find.text('2/2 paid'), findsOneWidget);
    },
  );

  testWidgets(
    'unavailable finalized snapshot never substitutes cached current person totals',
    (tester) async {
      await showHistory(
        tester,
        (request) async => http.Response(
          request.url.path.endsWith('/members') ? '[]' : '{}',
          request.url.path.endsWith('/members') ? 200 : 503,
        ),
        cachedReceipt: true,
      );
      expect(
        find.textContaining('Recorded settlements are unavailable'),
        findsOneWidget,
      );
      expect(find.text('Per Person'), findsNothing);
      expect(find.text('No recorded settlement rows.'), findsNothing);
      expect(find.text('Retry current history'), findsOneWidget);
    },
  );

  testWidgets(
    'empty bill list retains blank legacy settlement rows and exact row paid control',
    (tester) async {
      final writes = <http.Request>[];
      await showHistory(tester, (request) async {
        if (request.method == 'PATCH') {
          writes.add(request);
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/members')
                ? []
                : rawHistory('legacy_identity_review_required'),
          ),
          200,
        );
      });
      expect(find.textContaining('ownership needs review'), findsOneWidget);
      expect(find.text('Unnamed · recorded row 11'), findsOneWidget);
      expect(find.text('Unnamed · recorded row 12'), findsOneWidget);
      expect(find.textContaining('2.00'), findsOneWidget);
      expect(find.textContaining('3.00'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
      await tester.tap(find.text('Unnamed · recorded row 12'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single.url.path, '/api/tabs/9/settlements/12');
      expect(jsonDecode(writes.single.body), {'paid': true});
      expect(writes.single.headers['Authorization'], 'Bearer destination');
    },
  );

  testWidgets(
    'invalid settlement history retains raw rows without enabling a paid mutation',
    (tester) async {
      final writes = <http.Request>[];
      await showHistory(tester, (request) async {
        if (request.method != 'GET') writes.add(request);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/members')
                ? []
                : rawHistory('identity_review_required'),
          ),
          200,
        );
      });
      await tester.tap(find.text('Unnamed · recorded row 12'));
      await tester.pumpAndSettle();
      expect(find.text('Unnamed · recorded row 11'), findsOneWidget);
      expect(find.textContaining('ownership needs review'), findsOneWidget);
      expect(writes, isEmpty);
    },
  );

  testWidgets(
    'unavailable history with no bills has finite deliberate retry and legitimate empty recovery',
    (tester) async {
      var reads = 0;
      final writes = <http.Request>[];
      await showHistory(tester, (request) async {
        if (request.method != 'GET') writes.add(request);
        if (request.url.path.endsWith('/members')) {
          return http.Response('[]', 200);
        }
        reads++;
        if (reads == 1) return http.Response('{}', 503);
        return http.Response(
          '{"settlements":[],"identity_review_status":"ready","accounting_currency":"USD"}',
          200,
        );
      });
      expect(reads, 1);
      expect(
        find.textContaining('Recorded settlements are unavailable'),
        findsOneWidget,
      );
      expect(find.text('No recorded settlement rows.'), findsNothing);
      await tester.tap(find.text('Retry current history'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('No recorded settlement rows.'), findsOneWidget);
      expect(find.text('Retry current history'), findsNothing);
      expect(find.textContaining('0.00'), findsNothing);
      expect(writes, isEmpty);
    },
  );
}
