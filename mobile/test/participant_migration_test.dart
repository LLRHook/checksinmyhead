import 'dart:io';
import 'package:checks_frontend/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final version in [8, 9]) {
    test(
      'file-backed Drift$version to10 reopens preserving every old column and row',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'billington-drift$version-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/history.sqlite');
        final sql =
            File(
              'test/fixtures/drift${version}_identity.sql',
            ).readAsStringSync();
        final oldRows = <Map<String, dynamic>>[];
        final oldTabRows = <Map<String, dynamic>>[];
        var db = AppDatabase.forTesting(
          NativeDatabase(
            file,
            setup: (raw) {
              raw.execute(sql);
              raw.execute(
                "INSERT INTO tabs VALUES(3,'Trip','Raw','11',17,'tab-proof','https://billington.app/t/17?t=tab-proof',1,'member-proof','member',1,12345)",
              );
              for (var i = 0; i < 6; i++) {
                raw.execute(
                  "INSERT INTO recent_bills(id,bill_name,participants,participant_count,total,date,subtotal,tax,tip_amount,tip_percentage,items,color_value,created_at,share_url,currency_code,usd_exchange_rate,exchange_rate_date,exchange_rate_source) VALUES(?,?,'[\"Alex\",\"Alex\",\"\"]',3,1.005,'2001-01-01',1.005,0,0,0,'[{\"name\":\"Repeated\",\"price\":1.005,\"assignments\":{\"Alex\":100}}]',4280391411,12345,?,'JPY',0.01,'2001-01-01','synthetic-old')",
                  [
                    11 + i,
                    'row$i',
                    i == 0
                        ? null
                        : 'https://billington.app/b/${31 + i}?t=source-$i',
                  ],
                );
                if (version == 9) {
                  raw.execute(
                    'UPDATE recent_bills SET creation_handle=?, creation_snapshot=?,snapshot_version=1,key_locator=?,publication_attempted=?,publication_state=?,valuation_state=?,failure_code=?,remote_bill_id=?,authoritative_usd_total=?,intended_tab_id=?,attachment_state=?,saved_shares=?,receipt_metadata=? WHERE id=?',
                    [
                      i == 5 ? null : 'op-$i',
                      ' {"name":"Frozen bytes $i"} ',
                      'receipt-v1:op-$i',
                      i == 0 ? 0 : 1,
                      [
                        'pending',
                        'pending',
                        'blocked',
                        'published',
                        'published',
                        'imported',
                      ][i],
                      'frozen',
                      i == 2 ? 'keyAbsent' : null,
                      i > 2 ? 31 + i : null,
                      i > 2 ? 0 : null,
                      i == 4 ? 3 : null,
                      i == 4 ? 'attempted' : 'none',
                      '[{"name":"Alex","total":1.005}]',
                      '{"birthday_name":"Alex"}',
                      11 + i,
                    ],
                  );
                }
              }
              for (final row in raw.select('SELECT * FROM tabs ORDER BY id')) {
                oldTabRows.add(Map.of(row));
              }
              for (final row in raw.select(
                'SELECT * FROM recent_bills ORDER BY id',
              )) {
                oldRows.add(Map.of(row));
              }
            },
          ),
        );
        final rows = await db.getRecentBills();
        expect(rows, hasLength(6));
        expect(db.schemaVersion, 10);
        final upgraded =
            await db
                .customSelect('SELECT * FROM recent_bills ORDER BY id')
                .get();
        for (var i = 0; i < oldRows.length; i++) {
          for (final e in oldRows[i].entries) {
            expect(
              upgraded[i].data[e.key],
              e.value,
              reason: 'Drift$version row$i ${e.key}',
            );
          }
          expect(upgraded[i].data['creation_wire_version'], isNull);
          expect(upgraded[i].data['original_participant_map'], isNull);
          expect(upgraded[i].data['receipt_participants'], isNull);
        }
        final tabsAfter =
            await db.customSelect('SELECT * FROM tabs ORDER BY id').get();
        for (var i = 0; i < oldTabRows.length; i++) {
          for (final e in oldTabRows[i].entries) {
            expect(
              tabsAfter[i].data[e.key],
              e.value,
              reason: 'Drift$version tab$i ${e.key}',
            );
          }
        }
        final tab = (await db.getTabById(3))!;
        expect(tab.memberId, isNull);
        expect(tab.memberToken, 'member-proof');
        expect(tab.billIds, '11');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(db.close);
        expect((await db.getRecentBills()).map((b) => b.id).toSet(), {
          11,
          12,
          13,
          14,
          15,
          16,
        });
        expect(
          (await db.getBillById(12))!.shareUrl,
          'https://billington.app/b/32?t=source-1',
        );
        expect((await db.getTabById(3))!.memberToken, 'member-proof');
      },
    );
  }
}
