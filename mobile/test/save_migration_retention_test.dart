import 'dart:convert';
import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'save_receipt_test.dart' show Harness;

void main() {
  test(
    'schema8 upgrade retains raw native JPY links quotes and all legacy state',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              '''CREATE TABLE recent_bills(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,bill_name TEXT NOT NULL DEFAULT '',participants TEXT NOT NULL,participant_count INTEGER NOT NULL,total REAL NOT NULL,date TEXT NOT NULL,subtotal REAL NOT NULL,tax REAL NOT NULL,tip_amount REAL NOT NULL,tip_percentage REAL NULL,items TEXT NULL,color_value INTEGER NOT NULL DEFAULT 4280391411,created_at INTEGER NOT NULL,share_url TEXT NULL,currency_code TEXT NOT NULL DEFAULT 'USD',usd_exchange_rate REAL NOT NULL DEFAULT 1,exchange_rate_date TEXT NULL,exchange_rate_source TEXT NOT NULL DEFAULT 'native-usd')''',
            );
            raw.execute(
              '''INSERT INTO recent_bills VALUES(11,'Raw legacy','["Alex"]',1,1.005,'2001-01-01',1.005,0,0,0,'[{"name":"Raw","price":1.005,"assignments":{"Alex":-1}}]',4280391411,978307200,'https://billington.app/b/73?t=synthetic-legacy','JPY',0.01,'2001-01-01','synthetic-old')''',
            );
            raw.userVersion = 8;
          },
        ),
      );
      addTearDown(db.close);
      final row = (await db.getRecentBills()).single;
      expect(db.schemaVersion, 9);
      expect(row.id, 11);
      expect(row.total, 1.005);
      expect(row.currencyCode, 'JPY');
      expect(row.usdExchangeRate, .01);
      expect(row.exchangeRateDate, '2001-01-01');
      expect(row.shareUrl, contains('/b/73'));
      expect(jsonDecode(row.items!).single['assignments']['Alex'], -1);
      expect(row.creationHandle, isNull);
      expect(row.creationSnapshot, isNull);
      expect(row.keyLocator, isNull);
      expect(row.publicationAttempted, false);
      expect(row.publicationState, 'legacy');
      expect(row.authoritativeUsdTotal, isNull);
      expect(row.createdAt, DateTime.fromMillisecondsSinceEpoch(978307200000));
    },
  );
  test(
    'capacity evicts only an unreferenced completed row and preserves references',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final ids = <int>[];
      for (var i = 0; i < 30; i++) {
        ids.add(
          await h.db.saveBill(
            participants: [],
            personShares: {},
            items: [],
            subtotal: i.toDouble(),
            tax: 0,
            tipAmount: 0,
            total: i.toDouble(),
            shareUrl: 'https://billington.app/b/${i + 1}?t=synthetic',
          ),
        );
      }
      final tab = await h.tab();
      await h.db.updateTab(tab, TabsCompanion(billIds: Value('${ids.first}')));
      final result = await h.save();
      expect(result.localId, isNot(ids.first));
      expect(await h.db.getBillById(ids.first), isNotNull);
      expect((await h.db.getTabById(tab))!.billIds, '${ids.first}');
      expect(await h.db.getRecentBills(), hasLength(30));
    },
  );
  test(
    'import refresh cannot replace source snapshot native values frozen zero or credentials',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      final result = await h.save();
      final original = (await h.db.getBillById(result.localId))!;
      final imported = await h.owner.importRemoteTabBills(7, [
        {
          'id': 19,
          'currency_code': 'USD',
          'total': 999,
          'usd_total': 0,
          'participants': [
            {'name': 'Alex'},
          ],
          'person_shares': [
            {'person_name': 'Alex', 'total': 2},
          ],
        },
      ]);
      final after = (await h.db.getBillById(result.localId))!;
      expect(imported, [result.localId]);
      expect(after.creationSnapshot, original.creationSnapshot);
      expect(after.keyLocator, original.keyLocator);
      expect(after.currencyCode, 'EUR');
      expect(after.total, 25);
      expect(after.authoritativeUsdTotal, 31.25);
      expect(after.shareUrl, original.shareUrl);
      expect(
        RecentBillModel.fromData(after).generatePersonShares().values.single,
        2,
      );
    },
  );
  test(
    'unavailable foreign value is separate from valid authoritative frozen zero',
    () async {
      final h = Harness();
      addTearDown(h.db.close);
      h.replay = false;
      final result = await h.save();
      final row = (await h.db.getBillById(result.localId))!;
      expect(RecentBillModel.fromData(row).verifiedUsdTotal, isNull);
      await h.db.checkpointReceipt(
        row.id,
        const RecentBillsCompanion(
          valuationState: Value('frozen'),
          usdExchangeRate: Value(0.00001),
          exchangeRateDate: Value('2001-01-01'),
          exchangeRateSource: Value('synthetic-historical'),
          authoritativeUsdTotal: Value(0),
        ),
      );
      expect(
        RecentBillModel.fromData(
          (await h.db.getBillById(row.id))!,
        ).verifiedUsdTotal,
        0,
      );
    },
  );
}
