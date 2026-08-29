import 'package:checks_frontend/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('omitted currency metadata keeps legacy bills as native USD', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.saveBill(
      participants: const [],
      personShares: const {},
      items: const [],
      subtotal: 10,
      tax: 0,
      tipAmount: 0,
      total: 10,
    );

    final bill = (await db.getRecentBills()).single;
    expect(bill.currencyCode, 'USD');
    expect(bill.usdExchangeRate, 1);
    expect(bill.exchangeRateSource, 'native-usd');
  });

  test('persists the frozen foreign-currency audit fields', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.saveBill(
      participants: const [],
      personShares: const {},
      items: const [],
      subtotal: 100,
      tax: 0,
      tipAmount: 0,
      total: 100,
      currencyCode: 'MXN',
      usdExchangeRate: 0.053,
      exchangeRateDate: '2026-08-29',
      exchangeRateSource: 'frankfurter-v2-blended',
    );

    final bill = (await db.getRecentBills()).single;
    expect(bill.currencyCode, 'MXN');
    expect(bill.usdExchangeRate, 0.053);
    expect(bill.exchangeRateDate, '2026-08-29');
    expect(bill.exchangeRateSource, 'frankfurter-v2-blended');
  });

  test(
    'same numeric total in different currencies is not a duplicate',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      for (final currency in ['USD', 'EUR']) {
        await db.saveBill(
          participants: const [],
          personShares: const {},
          items: const [],
          subtotal: 10,
          tax: 0,
          tipAmount: 0,
          total: 10,
          currencyCode: currency,
          usdExchangeRate: currency == 'USD' ? 1 : 1.16,
          exchangeRateDate: currency == 'USD' ? null : '2026-08-29',
          exchangeRateSource:
              currency == 'USD' ? 'native-usd' : 'frankfurter-v2-blended',
        );
      }

      final bills = await db.getRecentBills();
      expect(
        bills.map((bill) => bill.currencyCode),
        containsAll(['USD', 'EUR']),
      );
      expect(bills, hasLength(2));
    },
  );

  test('upgrades a schema 7 legacy row with native USD defaults', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
          CREATE TABLE recent_bills (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            bill_name TEXT NOT NULL DEFAULT '',
            participants TEXT NOT NULL,
            participant_count INTEGER NOT NULL,
            total REAL NOT NULL,
            date TEXT NOT NULL,
            subtotal REAL NOT NULL,
            tax REAL NOT NULL,
            tip_amount REAL NOT NULL,
            tip_percentage REAL NULL,
            items TEXT NULL,
            color_value INTEGER NOT NULL DEFAULT 4280391411,
            created_at INTEGER NOT NULL,
            share_url TEXT NULL
          )
        ''');
        raw.execute(
          "INSERT INTO recent_bills (bill_name, participants, participant_count, total, date, subtotal, tax, tip_amount, created_at) VALUES ('Legacy', '[]', 0, 12.5, '2026-08-01', 12.5, 0, 0, 1754006400)",
        );
        raw.userVersion = 7;
      },
    );

    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);
    final bill = (await db.getRecentBills()).single;

    expect(bill.billName, 'Legacy');
    expect(bill.total, 12.5);
    expect(bill.currencyCode, 'USD');
    expect(bill.usdExchangeRate, 1);
    expect(bill.exchangeRateDate, isNull);
    expect(bill.exchangeRateSource, 'native-usd');
  });
}
