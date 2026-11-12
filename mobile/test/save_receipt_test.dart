import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/services/creation_key_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeCreationKeys implements CreationKeyStore {
  final values = <String, Uint8List>{};
  CreationKeyStatus? forced;
  int creates = 0;
  @override
  Future<CreationKeyResult> read(String locator) async {
    if (forced != null) return CreationKeyResult(forced!);
    final value = values[locator];
    return CreationKeyResult(
      value == null ? CreationKeyStatus.absent : CreationKeyStatus.available,
      value,
    );
  }

  @override
  Future<CreationKeyResult> createIfAbsent(String locator) async {
    creates++;
    values.putIfAbsent(
      locator,
      () => Uint8List.fromList(List.filled(32, creates)),
    );
    return read(locator);
  }
}

class CheckpointDatabase extends AppDatabase {
  CheckpointDatabase() : super.forTesting(NativeDatabase.memory());
  bool failRemoteCheckpoint = false;
  bool failAttempt = false;
  @override
  Future<void> checkpointReceipt(int id, RecentBillsCompanion values) {
    if ((failRemoteCheckpoint && values.remoteBillId.present) ||
        (failAttempt && values.publicationAttempted.present)) {
      throw StateError('synthetic checkpoint failure');
    }
    return super.checkpointReceipt(id, values);
  }
}

final alex = Person(name: 'Alex', color: Colors.blue);
final birthday = Person(name: 'Birthday', color: Colors.red);
BillSummaryData draft({double total = 25, String currency = 'EUR'}) =>
    BillSummaryData(
      participants: [alex, birthday],
      birthdayPerson: birthday,
      personShares: {alex: total, birthday: 0},
      items: [
        BillItem(name: 'Repeated', price: total * .6, assignments: {alex: 100}),
        BillItem(name: 'Repeated', price: total * .4, assignments: {alex: 100}),
      ],
      subtotal: total,
      tax: 0,
      tipAmount: 0,
      total: total,
      billName: 'Synthetic',
      tipPercentage: 18,
      isCustomTipAmount: true,
      currencyCode: currency,
      paymentMethods: const [
        {'name': 'Synthetic', 'identifier': 'fixture'},
      ],
    );

Map<String, dynamic> creationResponse(
  Map<String, dynamic> body, {
  int id = 19,
  double? usd,
  int? identityVersion,
}) {
  final currency = body['currency_code'] as String;
  final rate = currency == 'USD' ? 1.0 : 1.25;
  return {
    if (identityVersion == 2 ||
        (identityVersion == null &&
            (body['participants'] as List).isNotEmpty &&
            (body['participants'] as List).first.containsKey(
              'client_ref',
            ))) ...{
      'response_version': 2,
      'identity_version': 2,
      'identity_revision': 0,
      'participant_map': [
        for (var i = 0; i < (body['participants'] as List).length; i++)
          {
            'client_ref': body['participants'][i]['client_ref'],
            'participant_id': 100 + i,
          },
      ],
    },
    'bill_id': id,
    'access_token': 'synthetic-source-$id',
    'share_url': 'https://billington.app/b/$id?t=synthetic-source-$id',
    'currency_code': currency,
    'usd_exchange_rate': rate,
    'exchange_rate_date': currency == 'USD' ? '' : '2026-11-04',
    'exchange_rate_source':
        currency == 'USD' ? 'native-usd' : 'synthetic-frozen',
    'usd_total':
        usd ?? ((body['total'] as num).toDouble() * rate * 100).round() / 100,
  };
}

const capability =
    '{"capabilities":{"bill_creation_replay":{"version":1,"key_format":"base64url-32"}}}';

class Harness {
  Harness({AppDatabase? database, FakeCreationKeys? keyStore})
    : db = database ?? AppDatabase.forTesting(NativeDatabase.memory()),
      keys = keyStore ?? FakeCreationKeys() {
    api = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/app/version-policy') {
          return http.Response(replay ? capability : '{}', 200);
        }
        if (request.method == 'GET') {
          if (request.url.path.startsWith('/api/bills/')) {
            return http.Response('{"identity_revision":0}', 200);
          }
          return http.Response(jsonEncode(tabRead), 200);
        }
        if (request.url.path == '/api/bills') {
          posts++;
          final rows = await db.getRecentBills();
          final row = rows.singleWhere((b) => b.publicationState == 'pending');
          expect(
            row.publicationAttempted,
            isTrue,
            reason: 'HTTP must follow the durable attempt checkpoint',
          );
          expect(request.body, row.creationSnapshot);
          expect(
            request.headers['Idempotency-Key'],
            matches(RegExp(r'^[A-Za-z0-9_-]{43}$')),
          );
          if (onCreate != null) return onCreate!(request);
          return http.Response(
            jsonEncode(
              creationResponse(jsonDecode(request.body), identityVersion: 2),
            ),
            201,
          );
        }
        attachments++;
        if (onAttach != null) return onAttach!(request);
        return http.Response('{}', 200);
      }),
      baseUrl: 'https://synthetic.invalid',
    );
    owner = RecentBillsManager.withDependencies(
      database: db,
      api: api,
      keyStore: keys,
    );
  }
  final AppDatabase db;
  final FakeCreationKeys keys;
  late final ApiService api;
  late final RecentBillsManager owner;
  final requests = <http.Request>[];
  bool replay = true;
  int posts = 0;
  int attachments = 0;
  Map<String, dynamic> tabRead = {'bills': []};
  Future<http.Response> Function(http.Request)? onCreate;
  Future<http.Response> Function(http.Request)? onAttach;
  Future<SaveReceiptResult> save([String handle = 'operation-a']) =>
      owner.saveReceipt(operationHandle: handle, receipt: draft());
  Future<int> tab({bool finalized = false}) => db.insertTab(
    TabsCompanion(
      name: const Value('Synthetic trip'),
      backendId: const Value(7),
      accessToken: const Value('synthetic-destination'),
      memberToken: const Value('synthetic-member'),
      finalized: Value(finalized),
    ),
  );
}

void main() {
  test(
    'half-cent draft pending published and reopened totals preserve money',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final entry = BillData();
      addTearDown(entry.dispose);
      entry.subtotalController.text = '2.25';
      entry.taxController.text = '0.02';
      final receipt = BillSummaryData(
        participants: [alex],
        personShares: {alex: 2.68},
        items: [
          BillItem(name: 'L20 item', price: 2.25, assignments: {alex: 100}),
        ],
        subtotal: entry.subtotal,
        tax: entry.tax,
        tipAmount: entry.tipAmount,
        total: entry.total,
        tipPercentage: 18,
        billName: 'L20 half cent',
      );
      final rawTotal = entry.total;
      expect(rawTotal, 2.675);
      expect(CurrencyFormatter.billTotalForDisplay(entry.total), 2.68);
      expect(receipt.displayTotal, 2.68);
      h.onCreate = (_) async => http.Response('{}', 503);
      final result = await h.owner.saveReceipt(
        operationHandle: 'L20-half-cent',
        receipt: receipt,
      );
      final pending = (await h.db.getBillById(result.localId))!;
      expect(pending.total, rawTotal);
      expect(RecentBillModel.fromData(pending).displayTotal, 2.68);
      final requestBefore = pending.creationSnapshot!;
      final body = jsonDecode(requestBefore) as Map<String, dynamic>;
      expect(body['total'], rawTotal);
      expect((body['person_shares'] as List).single['total'], 2.68);
      h.onCreate = null;
      await h.owner.resumeReceipt(result.localId);
      final published = (await h.db.getBillById(result.localId))!;
      final reopened = RecentBillModel.fromData(published);
      expect(published.total, rawTotal);
      expect(published.creationSnapshot, requestBefore);
      expect(reopened.displayTotal, 2.68);
      expect(reopened.displayUSDTotal, 2.68);
      expect(BillSummaryData.fromRecentBill(reopened).displayTotal, 2.68);
      expect(
        h.requests
            .where((r) => r.method == 'POST' && r.url.path == '/api/bills')
            .every((r) => r.body == requestBefore),
        isTrue,
      );
    },
  );
  test(
    'EUR owner commits one native row and exact frozen checkpoint',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final result = await h.save();
      final row = (await h.db.getRecentBills()).single;
      expect(result.localId, row.id);
      expect(row.currencyCode, 'EUR');
      expect(row.total, 25);
      expect(row.authoritativeUsdTotal, 31.25);
      expect(row.remoteBillId, 19);
      expect(result.publication, PublicationState.published);
      expect(h.posts, 1);
      final model = RecentBillModel.fromData(row);
      expect(model.isCustomTipAmount, true);
      expect(model.birthdayName, 'Birthday');
      expect(model.generatePersonShares().map((p, v) => MapEntry(p.name, v)), {
        'Alex': 25,
        'Birthday': 0,
      });
      expect(model.getBillItems().map((i) => i.name), ['Repeated', 'Repeated']);
      expect(row.creationSnapshot, contains('"tip_percentage":18.0'));
    },
  );
  for (final status in [409, 429, 500, 503]) {
    test(
      'HTTP $status preserves the native receipt and explicit publication state',
      () async {
        final h = Harness();
        addTearDown(h.db.close);
        h.onCreate = (_) async => http.Response('{}', status);
        final result = await h.save();
        final row = (await h.db.getRecentBills()).single;
        expect(row.currencyCode, 'EUR');
        expect(row.publicationAttempted, true);
        expect(row.shareUrl, isNull);
        expect(row.authoritativeUsdTotal, isNull);
        expect(RecentBillModel.fromData(row).verifiedUsdTotal, isNull);
        expect(
          result.failure,
          status == 409
              ? SaveFailure.conflict
              : SaveFailure.publicationUnavailable,
        );
        expect(h.posts, 1);
        expect(h.attachments, 0);
      },
    );
  }
  test(
    'offline create keeps one native receipt without default USD valuation',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      h.onCreate =
          (_) async => throw const SocketException('synthetic offline');
      final result = await h.save();
      expect(result.message, contains('Saved on this device'));
      expect(result.shareUrl, isNull);
      expect(h.posts, 1);
      expect(
        RecentBillModel.fromData(
          (await h.db.getRecentBills()).single,
        ).generateUSDPersonShares(),
        isEmpty,
      );
    },
  );
  test(
    'foreign zero USD total is checkpointed and never replaced by native',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final result = await h.owner.saveReceipt(
        operationHandle: 'subcent',
        receipt: draft(total: .001),
      );
      final row = (await h.db.getBillById(result.localId))!;
      expect(row.authoritativeUsdTotal, 0);
      expect(RecentBillModel.fromData(row).usdTotal, 0);
    },
  );
  test(
    'exact-ID checkpoint survives a concurrently inserted different receipt',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      h.onCreate = (request) async {
        await h.db.saveBill(
          participants: [],
          personShares: {},
          items: [],
          subtotal: 7,
          tax: 0,
          tipAmount: 0,
          total: 7,
          billName: 'Other',
        );
        await h.db.customStatement(
          "UPDATE recent_bills SET created_at = created_at + 10 WHERE bill_name='Other'",
        );
        return http.Response(
          jsonEncode(
            creationResponse(jsonDecode(request.body), identityVersion: 2),
          ),
          201,
        );
      };
      final result = await h.save();
      final rows = await h.db.getRecentBills();
      expect(rows, hasLength(2));
      expect(rows.singleWhere((r) => r.id == result.localId).remoteBillId, 19);
      expect(rows.singleWhere((r) => r.billName == 'Other').shareUrl, isNull);
    },
  );
  test(
    'local insert transaction failure triggers no key or HTTP operation',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      await h.db.customStatement(
        "CREATE TRIGGER fixture_fail BEFORE INSERT ON recent_bills BEGIN SELECT RAISE(ABORT, 'synthetic local failure'); END",
      );
      await expectLater(h.save(), throwsA(anything));
      expect(await h.db.getRecentBills(), isEmpty);
      expect(h.requests, isEmpty);
      expect(h.keys.creates, 0);
    },
  );
  test(
    'same-handle Done retry overlap joins and later clears in-flight ownership',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final entered = Completer<void>(), release = Completer<void>();
      h.onCreate = (request) async {
        entered.complete();
        await release.future;
        return http.Response(
          jsonEncode(
            creationResponse(jsonDecode(request.body), identityVersion: 2),
          ),
          201,
        );
      };
      final first = h.save();
      final second = h.save();
      expect(identical(first, second), true);
      await entered.future;
      final row = (await h.db.getRecentBills()).single;
      final resume = h.owner.resumeReceipt(row.id);
      release.complete();
      expect((await first).localId, (await second).localId);
      expect((await resume).localId, row.id);
      expect(h.posts, 1);
      await h.owner.resumeReceipt(row.id);
      expect(h.posts, 1);
    },
  );
  test(
    'two identical receipts with independent handles remain distinct',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final first = await h.save('a');
      final second = await h.save('b');
      expect(first.localId, isNot(second.localId));
      expect(await h.db.getRecentBills(), hasLength(2));
      expect(h.keys.values.length, 2);
      expect(h.posts, 2);
    },
  );
  test(
    'remote commit plus local checkpoint failure recovers same key and snapshot',
    () async {
      final db = CheckpointDatabase()..failRemoteCheckpoint = true;
      final h = Harness(database: db);
      addTearDown(db.close);
      final first = await h.save();
      expect(first.failure, SaveFailure.checkpointFailed);
      expect(first.shareUrl, isNull);
      final original = (await db.getRecentBills()).single;
      db.failRemoteCheckpoint = false;
      final second = await h.owner.resumeReceipt(first.localId);
      expect(second.localId, first.localId);
      expect(second.publication, PublicationState.published);
      final posts =
          h.requests.where((r) => r.url.path == '/api/bills').toList();
      expect(posts[0].body, posts[1].body);
      expect(
        posts[0].headers['Idempotency-Key'],
        posts[1].headers['Idempotency-Key'],
      );
      expect(
        (await db.getBillById(first.localId))!.creationSnapshot,
        original.creationSnapshot,
      );
      expect(h.keys.creates, 1);
    },
  );
  test(
    'lost response close/reopen replays persisted bytes without current settings',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'billington-save-reopen-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/synthetic.sqlite');
      final first = Harness(
        database: AppDatabase.forTesting(NativeDatabase(file)),
      );
      first.onCreate =
          (_) async =>
              throw const SocketException('response lost after commit');
      final pending = await first.save();
      final row = (await first.db.getRecentBills()).single;
      await first.db.close();
      final reopened = Harness(
        database: AppDatabase.forTesting(NativeDatabase(file)),
        keyStore: first.keys,
      );
      addTearDown(reopened.db.close);
      final changed = draft().copyWith(
        billName: 'Different settings',
        paymentMethods: [],
      );
      final recovered = await reopened.owner.saveReceipt(
        operationHandle: 'operation-a',
        receipt: changed,
      );
      expect(recovered.localId, pending.localId);
      expect(reopened.keys.creates, 1);
      final recoveredRow = (await reopened.db.getRecentBills()).single;
      expect(recoveredRow.creationSnapshot, row.creationSnapshot);
      expect(recoveredRow.billName, 'Synthetic');
      expect(reopened.requests.last.body, row.creationSnapshot);
    },
  );
  test('attempt checkpoint failure cannot issue an HTTP POST', () async {
    final db = CheckpointDatabase()..failAttempt = true;
    final h = Harness(database: db);
    addTearDown(db.close);
    final result = await h.save();
    expect(result.failure, SaveFailure.checkpointFailed);
    expect(h.posts, 0);
    expect((await db.getRecentBills()).single.publicationAttempted, false);
  });
  for (final attempted in [false, true]) {
    for (final status in [
      CreationKeyStatus.absent,
      CreationKeyStatus.locked,
      CreationKeyStatus.error,
      CreationKeyStatus.unsupported,
    ]) {
      test(
        'crash window attempted=$attempted key=${status.name} never invents attempted identity',
        () async {
          final h = Harness()..replay = false;
          addTearDown(h.db.close);
          final saved = await h.save();
          final row = (await h.db.getRecentBills()).single;
          await h.db.checkpointReceipt(
            row.id,
            RecentBillsCompanion(publicationAttempted: Value(attempted)),
          );
          h.keys.values.clear();
          h.keys.forced = status;
          final creates = h.keys.creates;
          h.replay = true;
          final result = await h.owner.resumeReceipt(saved.localId);
          expect(h.posts, 0);
          expect(
            h.keys.creates,
            creates +
                (!attempted && status == CreationKeyStatus.absent ? 1 : 0),
          );
          expect(result.shareUrl, isNull);
          expect(await h.db.getRecentBills(), hasLength(1));
          if (attempted && status == CreationKeyStatus.absent) {
            expect(result.publication, PublicationState.blocked);
          }
        },
      );
    }
  }
  test(
    'crash before key creation safely creates only before first attempted publication',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final saved = await h.save();
      h.keys.values.clear();
      h.replay = true;
      final result = await h.owner.resumeReceipt(saved.localId);
      expect(result.publication, PublicationState.published);
      expect(h.posts, 1);
    },
  );
  test(
    'crash after key creation reuses existing key before attempted marker',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final saved = await h.save();
      final original = h.keys.values.values.single;
      h.replay = true;
      await h.owner.resumeReceipt(saved.localId);
      expect(h.keys.creates, 1);
      expect(
        h.requests.last.headers['Idempotency-Key'],
        base64Url.encode(original).replaceAll('=', ''),
      );
    },
  );
  test(
    'missing capability fails closed with no unkeyed or automatic POST fallback',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final result = await h.save();
      expect(h.posts, 0);
      expect(result.failure, SaveFailure.capabilityUnavailable);
      expect((await h.db.getRecentBills()).single.publicationAttempted, false);
    },
  );
  for (final field in [
    'usd_total',
    'usd_exchange_rate',
    'exchange_rate_date',
    'share_url',
    'currency_code',
  ]) {
    test('invalid persisted201 $field keeps recovery pending', () async {
      final h = Harness();
      addTearDown(h.db.close);
      h.onCreate = (request) async {
        final body = creationResponse(jsonDecode(request.body));
        body.remove(field);
        return http.Response(jsonEncode(body), 201);
      };
      final result = await h.save();
      expect(result.shareUrl, isNull);
      expect(result.publication, PublicationState.pending);
      expect(h.posts, 1);
      expect((await h.db.getRecentBills()).single.publicationAttempted, true);
    });
  }
  test(
    'unknown snapshot version is explicit review and never rebuilt',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      final result = await h.save();
      await h.db.checkpointReceipt(
        result.localId,
        const RecentBillsCompanion(snapshotVersion: Value(99)),
      );
      h.replay = true;
      final reviewed = await h.owner.resumeReceipt(result.localId);
      expect(reviewed.failure, SaveFailure.snapshotReview);
      expect(h.posts, 0);
    },
  );
  test('ambiguous history and imported snapshots never auto-publish', () async {
    final h = Harness();
    addTearDown(h.db.close);
    final legacy = await h.db.saveBill(
      participants: [alex],
      personShares: {alex: 25},
      items: [],
      subtotal: 25,
      tax: 0,
      tipAmount: 0,
      total: 25,
    );
    final imports = await h.owner.importRemoteTabBills(7, [
      {
        'id': 19,
        'currency_code': 'EUR',
        'total': 25,
        'subtotal': 25,
        'participants': [
          {'name': 'Alex'},
        ],
      },
    ]);
    await h.owner.retryPendingUploads();
    expect(h.requests, isEmpty);
    await expectLater(
      h.owner.retrySingleBillUpload(legacy),
      throwsA(isA<BillValidationException>()),
    );
    await expectLater(
      h.owner.retrySingleBillUpload(imports.single),
      throwsA(isA<BillValidationException>()),
    );
    expect(
      RecentBillModel.fromData(
        (await h.db.getBillById(imports.single))!,
      ).verifiedUsdTotal,
      isNull,
    );
  });
  test(
    'history capacity cannot evict pending or referenced authority',
    () async {
      final h = Harness()..replay = false;
      addTearDown(h.db.close);
      for (var i = 0; i < AppDatabase.maxRecentBills; i++) {
        await h.save('pending-$i');
      }
      final before = (await h.db.getRecentBills()).map((b) => b.id).toList();
      await expectLater(h.save('overflow'), throwsA(isA<StateError>()));
      expect((await h.db.getRecentBills()).map((b) => b.id), before);
      expect(h.posts, 0);
    },
  );
  test(
    'authorized attachment uses exact local/remote/source/destination/member identities',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final tab = await h.tab();
      final result = await h.owner.saveReceipt(
        operationHandle: 'attached',
        receipt: draft(),
        intendedTabId: tab,
      );
      expect(result.attachment, AttachmentState.attached);
      expect(h.posts, 1);
      expect(h.attachments, 1);
      final request = h.requests.last;
      expect(request.url.path, '/api/tabs/7/bills');
      expect(request.headers['Authorization'], 'Bearer synthetic-destination');
      expect(request.headers['X-Member-Token'], 'synthetic-member');
      expect(jsonDecode(request.body), {
        'bill_id': 19,
        'bill_token': 'synthetic-source-19',
        'expected_revision': 0,
      });
      expect((await h.db.getTabById(tab))!.billIds, '${result.localId}');
    },
  );
  test(
    'lost attachment response reconciles known association after finalization',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final tab = await h.tab();
      h.onAttach = (_) async {
        if (h.attachments > 1) return http.Response('{}', 200);
        h.tabRead = {
          'finalized': true,
          'bills': [
            {'id': 19},
          ],
        };
        await h.db.updateTab(tab, const TabsCompanion(finalized: Value(true)));
        throw const SocketException('lost attach response');
      };
      final result = await h.owner.saveReceipt(
        operationHandle: 'lost-attach',
        receipt: draft(),
        intendedTabId: tab,
      );
      expect(result.attachment, AttachmentState.attached);
      expect(h.attachments, 2);
      await h.owner.resumeReceipt(result.localId);
      expect(h.attachments, 2);
      expect(h.posts, 1);
    },
  );
  test(
    'failed attachment remains published and finalized retry reads before rejecting writes',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final tab = await h.tab();
      h.onAttach = (_) async => http.Response('{}', 503);
      final result = await h.owner.saveReceipt(
        operationHandle: 'attach-pending',
        receipt: draft(),
        intendedTabId: tab,
      );
      expect(result.publication, PublicationState.published);
      expect(result.shareUrl, isNotNull);
      expect(result.attachment, AttachmentState.attempted);
      await h.db.updateTab(tab, const TabsCompanion(finalized: Value(true)));
      h.tabRead = {
        'finalized': true,
        'bills': [
          {'id': 19},
        ],
      };
      h.onAttach = (_) async => http.Response('{}', 200);
      expect(
        (await h.owner.resumeReceipt(result.localId)).attachment,
        AttachmentState.attached,
      );
      expect(h.posts, 1);
      expect(h.attachments, 2);
    },
  );
  test(
    'published receipt with unavailable destination remains standalone and attach-pending',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final result = await h.owner.saveReceipt(
        operationHandle: 'no-destination',
        receipt: draft(),
        intendedTabId: 999,
      );
      expect(result.publication, PublicationState.published);
      expect(result.attachment, AttachmentState.pending);
      expect(result.failure, SaveFailure.destinationUnavailable);
      expect(h.posts, 1);
      expect(h.attachments, 0);
    },
  );
  test(
    'null frozen response fields cannot silently become zero or identity',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      h.onCreate =
          (request) async => http.Response(
            jsonEncode({
              ...creationResponse(jsonDecode(request.body)),
              'usd_total': null,
            }),
            201,
          );
      final result = await h.owner.saveReceipt(
        operationHandle: 'null-zero',
        receipt: draft(total: .001),
      );
      expect(result.failure, SaveFailure.invalidResponse);
      expect(result.shareUrl, isNull);
    },
  );
  test(
    'creation redirects never forward the recovery capability or retry POST',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      h.onCreate = (request) async {
        expect(request.followRedirects, false);
        expect(request.maxRedirects, 0);
        return http.Response(
          '',
          303,
          headers: {'location': 'https://different.invalid'},
        );
      };
      final result = await h.save();
      expect(result.publication, PublicationState.pending);
      expect(h.posts, 1);
    },
  );
  test(
    'oversized creation response preserves the single attempted receipt',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      h.onCreate = (request) async => http.Response('x' * 65537, 201);
      final result = await h.save();
      expect(result.failure, SaveFailure.invalidResponse);
      expect(h.posts, 1);
      expect(await h.db.getRecentBills(), hasLength(1));
    },
  );
}
