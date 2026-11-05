// Explicit live selection only; launched by the strict owned-schema fixture.
import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../save_receipt_test.dart' show FakeCreationKeys;

class CaptureCreation extends http.BaseClient {
  final http.Client inner = http.Client();
  bool lose = true;
  final bodies = <String>[];
  final keys = <String>[];
  final receipts = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'POST' || request.url.path != '/api/bills') {
      return inner.send(request);
    }
    bodies.add((request as http.Request).body);
    keys.add(request.headers['Idempotency-Key']!);
    expect(request.headers['X-Billington-Identity-Version'], '2');
    final response = await http.Response.fromStream(await inner.send(request));
    receipts.add(response.body);
    if (lose) {
      lose = false;
      throw const SocketException('synthetic lost original201');
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() => inner.close();
}

class CheckpointFile extends AppDatabase {
  CheckpointFile(File file) : super.forTesting(NativeDatabase(file));
  bool fail = false;
  bool failAttachment = false;
  @override
  Future<void> checkpointAttachment(int id, int tabId) async {
    if (failAttachment) {
      throw StateError('synthetic attach checkpoint uncertainty');
    }
    return super.checkpointAttachment(id, tabId);
  }

  @override
  Future<void> checkpointReceipt(int id, RecentBillsCompanion values) {
    if (fail && values.remoteBillId.present) {
      throw StateError('synthetic original map checkpoint uncertainty');
    }
    return super.checkpointReceipt(id, values);
  }
}

class LiveClientBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  LiveClientBinding();
  SharedPreferences.setMockInitialValues({});
  test(
    'maintained mobile builder save lost201 checkpoint reopen and two independently authenticated members',
    () async {
      final base = Platform.environment['BILLINGTON_CD_HTTP'];
      final out = Platform.environment['BILLINGTON_CD_OUTPUT'];
      if (base == null || out == null || Uri.parse(base).host != '127.0.0.1') {
        fail('Strict live loopback fixture required');
      }
      final dir = Directory(File(out).parent.path);
      if (Platform.environment['BILLINGTON_CD_PHASE'] == 'recover-attachment') {
        final fixture =
            jsonDecode(await File(out).readAsString()) as Map<String, dynamic>;
        final db = CheckpointFile(File(fixture['local_database'] as String));
        addTearDown(db.close);
        final api = ApiService(baseUrl: base);
        final owner = RecentBillsManager.withDependencies(
          database: db,
          api: api,
          keyStore: FakeCreationKeys(),
        );
        addTearDown(owner.dispose);
        await db.updateTab(
          fixture['local_tab_id'] as int,
          const TabsCompanion(finalized: Value(true)),
        );
        final result = await owner.resumeReceipt(
          fixture['local_receipt_id'] as int,
        );
        expect(result.attachment, AttachmentState.attached);
        expect(result.failure, isNull);
        final row = (await db.getBillById(result.localId))!;
        expect(row.originalParticipantMap, fixture['original_map']);
        expect(row.creationSnapshot, fixture['original_body']);
        return;
      }
      final file = File('${dir.path}/a.sqlite');
      final capture = CaptureCreation();
      addTearDown(capture.close);
      final api = ApiService(baseUrl: base, client: capture);
      final keys = FakeCreationKeys();
      var db = CheckpointFile(file);
      var owner = RecentBillsManager.withDependencies(
        database: db,
        api: api,
        keyStore: keys,
      );
      final people = [
        for (final name in ['Alex', 'Alex', '', 'Σ', 'ς', 'Birthday'])
          Person(name: name, color: Colors.blue),
      ];
      final receipt = BillSummaryData(
        participants: people,
        personShares: {for (var i = 0; i < 6; i++) people[i]: i == 5 ? 0 : 2},
        items: [
          for (var i = 0; i < 5; i++)
            BillItem(name: 'Repeated', price: 2, assignments: {people[i]: 100}),
        ],
        birthdayPerson: people.last,
        subtotal: 10,
        tax: 0,
        tipAmount: 0,
        total: 10,
        billName: 'Matched identity',
      );
      final first = await owner.saveReceipt(
        operationHandle: 'live-cd-receipt',
        receipt: receipt,
      );
      expect(first.publication, PublicationState.pending);
      expect(capture.receipts, hasLength(1));
      var row = (await db.getBillById(first.localId))!;
      final snapshot = row.creationSnapshot;
      await db.close();
      owner.dispose();
      db = CheckpointFile(file)..fail = true;
      owner = RecentBillsManager.withDependencies(
        database: db,
        api: api,
        keyStore: keys,
      );
      final second = await owner.resumeReceipt(first.localId);
      expect(second.failure, SaveFailure.checkpointFailed);
      expect((await db.getBillById(row.id))!.originalParticipantMap, isNull);
      await db.close();
      owner.dispose();
      db = CheckpointFile(file);
      addTearDown(db.close);
      owner = RecentBillsManager.withDependencies(
        database: db,
        api: api,
        keyStore: keys,
      );
      addTearDown(owner.dispose);
      final recovered = await owner.resumeReceipt(first.localId);
      expect(recovered.publication, PublicationState.published);
      row = (await db.getBillById(row.id))!;
      expect(row.creationSnapshot, snapshot);
      expect(capture.bodies, hasLength(3));
      expect(capture.bodies.toSet(), {snapshot});
      expect(capture.keys.toSet(), hasLength(1));
      expect(capture.receipts.toSet(), hasLength(1));
      expect(row.originalParticipantMap, isNotNull);
      expect(row.creationResponseVersion, 2);
      final tabs = TabManager.withDependencies(
        database: db,
        receipts: owner,
        api: api,
      );
      addTearDown(tabs.dispose);
      final creator = await tabs.createTab(
        'Synthetic trip',
        creatorDisplayName: 'Alex',
      );
      expect(creator, isNotNull);
      expect(creator!.memberId, greaterThan(0));
      expect((await db.getTabById(creator.id!))!.memberId, creator.memberId);
      db.failAttachment = true;
      expect(await tabs.addBillsToTab(creator.id!, [row.id]), false);
      expect((await db.getBillById(row.id))!.attachmentState, 'attempted');
      final dbB = AppDatabase.forTesting(
        NativeDatabase(File('${dir.path}/b.sqlite')),
      );
      addTearDown(dbB.close);
      final ownerB = RecentBillsManager.withDependencies(
        database: dbB,
        api: api,
        keyStore: FakeCreationKeys(),
      );
      addTearDown(ownerB.dispose);
      final tabsB = TabManager.withDependencies(
        database: dbB,
        receipts: ownerB,
        api: api,
      );
      addTearDown(tabsB.dispose);
      final joined = await tabsB.joinTab(creator.shareUrl!, 'Alex');
      expect(joined, isNotNull);
      expect(joined!.memberId, isNot(creator.memberId));
      final same = await tabsB.joinTab(
        creator.shareUrl!,
        'Different suggested label',
      );
      expect(same!.memberId, joined.memberId);
      final me = await api.getCurrentMember(
        creator.backendId!,
        creator.accessToken!,
        joined.memberToken!,
      );
      expect(me.memberId, joined.memberId);
      final sourceUri = Uri.parse(row.shareUrl!);
      final current = await api.getBillIdentity(
        '${row.remoteBillId}',
        sourceUri.queryParameters['t']!,
      );
      expect(current.revision, 1);
      expect(current.participants, hasLength(6));
      expect(
        current.participants.every((p) => p.bindingState == 'unbound'),
        true,
      );
      // A separate tiny receipt leaves the primary bill/revisions unchanged.
      // Supplying the source field exercises operation-specific real transport:
      // strict create/request reject an extra bill_token, rename/decision allow it.
      final probePerson = Person(name: 'Probe', color: Colors.blue);
      final probeSave = await owner.saveReceipt(
        operationHandle: 'strict-source-body-probe',
        receipt: BillSummaryData(
          participants: [probePerson],
          personShares: {probePerson: 1},
          items: [
            BillItem(name: 'Probe', price: 1, assignments: {probePerson: 100}),
          ],
          subtotal: 1,
          tax: 0,
          tipAmount: 0,
          total: 1,
          billName: 'Strict source body probe',
        ),
      );
      expect(probeSave.publication, PublicationState.published);
      final probeRow = (await db.getBillById(probeSave.localId))!;
      final probeTab =
          (await tabs.createTab(
            'Strict DTO probe',
            creatorDisplayName: 'Probe',
          ))!;
      db.failAttachment = false;
      expect(await tabs.addBillsToTab(probeTab.id!, [probeRow.id]), true);
      final probeSource = Uri.parse(probeRow.shareUrl!).queryParameters['t']!;
      final created = await api.participantCommand(
        billId: '${probeRow.remoteBillId}',
        token: probeTab.accessToken!,
        tabId: '${probeTab.backendId}',
        memberToken: probeTab.memberToken,
        expectedRevision: 1,
        clientRef: 'strict-command-probe',
        label: '',
        billToken: probeSource,
      );
      expect(created.revision, 2);
      expect(created.participant.bindingState, 'unbound');
      final renamed = await api.participantCommand(
        billId: '${probeRow.remoteBillId}',
        token: probeTab.accessToken!,
        tabId: '${probeTab.backendId}',
        memberToken: probeTab.memberToken,
        participantId: created.participant.id,
        expectedRevision: 2,
        label: 'Renamed probe',
        billToken: probeSource,
      );
      expect(renamed.revision, 3);
      final requested = await api.participantCommand(
        billId: '${probeRow.remoteBillId}',
        token: probeTab.accessToken!,
        tabId: '${probeTab.backendId}',
        memberToken: probeTab.memberToken,
        participantId: created.participant.id,
        expectedRevision: 3,
        bindingRequest: true,
        billToken: probeSource,
      );
      expect(requested.revision, 4);
      expect(requested.participant.bindingState, 'pending');
      final rejected = await api.participantCommand(
        billId: '${probeRow.remoteBillId}',
        token: probeTab.accessToken!,
        tabId: '${probeTab.backendId}',
        memberToken: probeTab.memberToken,
        participantId: created.participant.id,
        expectedRevision: 4,
        decision: 'reject',
        requestRevision: 4,
        memberId: probeTab.memberId,
        billToken: probeSource,
      );
      expect(rejected.revision, 5);
      expect(rejected.participant.bindingState, 'unbound');
      final probeGraph = await api.getCurrentBill(
        billId: '${probeRow.remoteBillId}',
        token: probeTab.accessToken!,
        tabId: '${probeTab.backendId}',
        memberToken: probeTab.memberToken,
      );
      final probeItem =
          (probeGraph['items'] as List).single as Map<String, dynamic>;
      final claimAck = await api.updateLazyBillItemAssignments(
        billId: '${probeRow.remoteBillId}',
        token: probeTab.accessToken!,
        tabId: '${probeTab.backendId}',
        memberToken: probeTab.memberToken,
        expectedRevision: 5,
        updates: [
          {
            'item_id': probeItem['id'],
            'expected_updated_at': probeItem['updated_at'],
            'assignments': [
              {'participant_id': created.participant.id, 'percentage': 100},
            ],
          },
        ],
      );
      expect(claimAck, isNull);
      final afterClaim = await api.getCurrentBill(
        billId: '${probeRow.remoteBillId}',
        token: probeTab.accessToken!,
        tabId: '${probeTab.backendId}',
        memberToken: probeTab.memberToken,
      );
      expect(afterClaim['identity_revision'], 6);
      expect(
        (afterClaim['person_shares'] as List).singleWhere(
          (s) => s['participant_id'] == created.participant.id,
        )['total'],
        1,
      );
      await File(out).writeAsString(
        jsonEncode({
          'local_database': file.path,
          'local_tab_id': creator.id,
          'local_receipt_id': row.id,
          'original_map': row.originalParticipantMap,
          'base': base,
          'bill_id': row.remoteBillId,
          'source': sourceUri.queryParameters['t'],
          'original_body': snapshot,
          'key': capture.keys.first,
          'original_response': capture.receipts.first,
          'tab_id': creator.backendId,
          'tab_token': creator.accessToken,
          'creator_id': creator.memberId,
          'creator_token': creator.memberToken,
          'member_id': joined.memberId,
          'member_token': joined.memberToken,
          'participant_ids': current.participants.map((p) => p.id).toList(),
          'strict_source_body_probe': true,
        }),
      );
    },
  );
}
