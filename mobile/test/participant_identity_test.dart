import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:checks_frontend/screens/lazy_bill_claim_state.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'save_receipt_test.dart'
    show Harness, FakeCreationKeys, creationResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'receipt registry preserves duplicate blank Unicode identities after file reopen rename and birthday',
    () async {
      final dir = await Directory.systemTemp.createTemp('billington-identity-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/receipt.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      final keys = FakeCreationKeys();
      final h = Harness(database: db, keyStore: keys)..replay = false;
      final people = [
        for (final label in ['Alex', 'Alex', 'alex', '', 'Σ', 'ς'])
          Person(name: label, color: Colors.blue),
      ];
      final result = await h.owner.saveReceipt(
        operationHandle: 'occurrences',
        receipt: BillSummaryData(
          participants: people,
          personShares: {for (final p in people) p: p == people.last ? 0 : 1},
          birthdayPerson: people.last,
          items: [
            BillItem(
              name: 'Repeated',
              price: 5,
              assignments: {for (final p in people.take(5)) p: 20},
            ),
          ],
          subtotal: 5,
          tax: 0,
          tipAmount: 0,
          total: 5,
        ),
      );
      final before = (await db.getBillById(result.localId))!;
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      final row = (await db.getBillById(result.localId))!;
      expect(row.creationSnapshot, before.creationSnapshot);
      expect(row.creationWireVersion, 2);
      expect(row.snapshotVersion, 2);
      final model = RecentBillModel.fromData(row);
      expect(model.participants.toSet(), hasLength(6));
      expect(model.participants, model.participants);
      expect(
        model.getBillItems().single.assignments.keys.toSet(),
        people.take(5).toSet(),
      );
      expect(model.generatePersonShares().keys.toSet(), people.toSet());
      expect(model.birthdayRef, people.last.clientRef);
      final renamed = people.first.copyWith(
        name: 'Changed',
        participantId: 71,
        color: Colors.red,
      );
      expect(renamed.clientRef, people.first.clientRef);
      expect(renamed.allocationLabel, 'Alex');
      expect(model.getBillItems().single.assignments[renamed], 20);
      expect(model.generatePersonShares()[renamed], 1);
    },
  );
  test(
    'new v2 original map is exact ordered unique and atomic with source authority',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final result = await h.save();
      final row = (await h.db.getBillById(result.localId))!;
      expect(row.creationResponseVersion, 2);
      expect(row.originalParticipantMap, isNotNull);
      final body = jsonDecode(row.creationSnapshot!);
      final map = jsonDecode(row.originalParticipantMap!);
      expect(
        map.map((m) => m['client_ref']),
        body['participants'].map((p) => p['client_ref']),
      );
      expect(row.remoteBillId, 19);
      expect(
        row.currentIdentityRevision,
        isNull,
        reason: 'original revision0 is historical, not a current revision',
      );
    },
  );
  for (final defect in [
    'missing',
    'reordered',
    'duplicate_id',
    'extra',
    'wrong_version',
  ]) {
    test(
      'original201 $defect map retains the same key and bytes for explicit recovery',
      () async {
        final h = Harness();
        addTearDown(h.db.close);
        final requests = <http.Request>[];
        h.onCreate = (request) async {
          requests.add(request);
          final response = creationResponse(jsonDecode(request.body));
          final map = response['participant_map'] as List;
          switch (defect) {
            case 'missing':
              response.remove('participant_map');
            case 'reordered':
              response['participant_map'] = map.reversed.toList();
            case 'duplicate_id':
              map.last['participant_id'] = map.first['participant_id'];
            case 'extra':
              map.first['ownership'] = true;
            case 'wrong_version':
              response['response_version'] = 1;
          }
          return http.Response(jsonEncode(response), 201);
        };
        final result = await h.save();
        var row = (await h.db.getBillById(result.localId))!;
        expect(row.publicationState, 'pending');
        expect(row.remoteBillId, isNull);
        expect(row.originalParticipantMap, isNull);
        final bytes = row.creationSnapshot;
        final locator = row.keyLocator;
        h.onCreate = (request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(creationResponse(jsonDecode(request.body))),
            201,
          );
        };
        await h.owner.resumeReceipt(row.id);
        row = (await h.db.getBillById(row.id))!;
        expect(row.publicationState, 'published');
        expect(row.keyLocator, locator);
        expect(row.creationSnapshot, bytes);
        expect(
          requests[0].headers['Idempotency-Key'],
          requests[1].headers['Idempotency-Key'],
        );
        expect(requests[0].headers['X-Billington-Identity-Version'], '2');
        expect(requests[0].body, requests[1].body);
      },
    );
  }
  test(
    'suggestion and group additions copy fresh refs and reject none of duplicate blank casefold labels',
    () {
      final provider = ParticipantsProvider();
      addTearDown(provider.dispose);
      final p = Person(name: 'Alex', color: Colors.blue);
      provider.addGroup([p, p]);
      provider.addPerson('alex');
      provider.addPerson('');
      expect(provider.participants, hasLength(4));
      expect(
        provider.participants.map((p) => p.clientRef).toSet(),
        hasLength(4),
      );
      final first = provider.participants.first;
      provider.renamePerson(0, 'Renamed');
      expect(provider.participants.first, first);
    },
  );
  test(
    'paid locks use exact occurrence IDs and cannot lock a same-label sibling',
    () {
      final shares = [
        {'participant_id': 11, 'person_name': 'Alex', 'paid': true},
      ];
      expect(
        isLazyItemFullyPaid([
          {'participant_id': 12, 'person_name': 'Alex', 'percentage': 100},
        ], shares),
        false,
      );
      expect(
        isLazyItemFullyPaid([
          {'participant_id': 11, 'person_name': 'Renamed', 'percentage': 100},
        ], shares),
        true,
      );
    },
  );
}
