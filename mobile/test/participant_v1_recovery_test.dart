import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'save_receipt_test.dart' show FakeCreationKeys;

void main() {
  test(
    'actual frozen Drift9 attempted-v1 reopens replays original HTTP bytes key absent-header and lost201 again',
    () async {
      const original =
          ' { "name":"Frozen v1", "subtotal":1, "total":1, "currency_code":"USD", "participants":[{"name":"Alex"}], "items":[{"name":"Meal","price":1,"assignments":[{"person_name":"Alex","percentage":100}]}] }\n';
      const acknowledgment =
          '{"bill_id":73,"access_token":"original-source","share_url":"https://billington.app/b/73?t=original-source","currency_code":"USD","usd_exchange_rate":1,"exchange_rate_date":"","exchange_rate_source":"native-usd","usd_total":1}';
      final dir = await Directory.systemTemp.createTemp(
        'billington-v1-recovery-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/history.sqlite');
      final keys =
          FakeCreationKeys()
            ..values['receipt-v1:old-operation'] = Uint8List.fromList(
              List.filled(32, 17),
            );
      final sent = <({String body, String? key, String? identity})>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        if (request.uri.path == '/api/app/version-policy') {
          request.response.write(
            '{"capabilities":{"bill_creation_replay":{"version":1,"key_format":"base64url-32"},"participant_identity":{"version":2}}}',
          );
          await request.response.close();
          return;
        }
        sent.add((
          body: await utf8.decodeStream(request),
          key: request.headers.value('Idempotency-Key'),
          identity: request.headers.value('X-Billington-Identity-Version'),
        ));
        if (sent.length == 1) {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.destroy();
          return;
        }
        request.response.statusCode = 201;
        request.response.write(acknowledgment);
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
        await subscription.cancel();
      });
      var db = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute(
              File('test/fixtures/drift9_identity.sql').readAsStringSync(),
            );
            raw.execute(
              "INSERT INTO recent_bills(id,bill_name,participants,participant_count,total,date,subtotal,tax,tip_amount,created_at,creation_handle,creation_snapshot,snapshot_version,key_locator,publication_attempted,publication_state,valuation_state) VALUES(41,'Current display differs','[\"Changed current settings\"]',1,1,'2001-01-01',1,0,0,12345,'old-operation',?,1,'receipt-v1:old-operation',1,'pending','native')",
              [original],
            );
          },
        ),
      );
      final api = ApiService(baseUrl: 'http://127.0.0.1:${server.port}');
      var owner = RecentBillsManager.withDependencies(
        database: db,
        api: api,
        keyStore: keys,
      );
      final first = await owner.resumeReceipt(41);
      expect(first.publication, PublicationState.pending);
      final before = (await db.getBillById(41))!;
      expect(before.creationWireVersion, isNull);
      expect(before.originalParticipantMap, isNull);
      expect(before.creationSnapshot, original);
      await db.close();
      owner.dispose();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      owner = RecentBillsManager.withDependencies(
        database: db,
        api: api,
        keyStore: keys,
      );
      addTearDown(owner.dispose);
      final recovered = await owner.resumeReceipt(41);
      expect(recovered.publication, PublicationState.published);
      final after = (await db.getBillById(41))!;
      expect(sent, hasLength(2));
      expect(sent.first.body, original);
      expect(sent.last.body, original);
      expect(sent.first.key, sent.last.key);
      expect(sent.first.identity, isNull);
      expect(sent.last.identity, isNull);
      expect(keys.creates, 0);
      expect(after.keyLocator, before.keyLocator);
      expect(after.creationSnapshot, original);
      expect(after.remoteBillId, 73);
      expect(after.shareUrl, contains('original-source'));
      expect(after.creationResponseVersion, isNull);
      expect(after.originalParticipantMap, isNull);
      expect(after.currentIdentityRevision, isNull);
    },
  );
}
