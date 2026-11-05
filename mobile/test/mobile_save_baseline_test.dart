import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'independent identical receipt saves remain distinct through owner',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final owner = RecentBillsManager.withDependencies(
        database: db,
        api: ApiService(),
      );
      addTearDown(db.close);
      for (var i = 0; i < 2; i++) {
        await owner.saveBill(
          participants: [],
          personShares: {},
          items: [],
          subtotal: 20,
          tax: 2,
          tipAmount: 3,
          total: 25,
          billName: 'EUR',
          currencyCode: 'EUR',
        );
      }
      expect(await db.getRecentBills(), hasLength(2));
    },
  );
  test('owner propagates local transaction failure', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "CREATE TRIGGER fixture_fail BEFORE INSERT ON recent_bills BEGIN SELECT RAISE(ABORT, 'synthetic local failure'); END",
    );
    final owner = RecentBillsManager.withDependencies(
      database: db,
      api: ApiService(),
    );
    await expectLater(
      owner.saveBill(
        participants: [],
        personShares: {},
        items: [],
        subtotal: 20,
        tax: 2,
        tipAmount: 3,
        total: 25,
        billName: 'EUR',
        currencyCode: 'EUR',
      ),
      throwsA(anything),
    );
  });
  test('maintained rate field accepts integer JSON number', () async {
    final api = ApiService(
      client: MockClient((_) async => http.Response('{"rate":2}', 200)),
    );
    expect(await api.getCurrencyRate('USD', 'ZAR'), 2);
  });
  test('authoritative frozen foreign zero stays valid', () {
    final response = BillUploadResponse.fromJson({
      'bill_id': 1,
      'access_token': 'synthetic',
      'share_url': 'https://billington.app/b/1?t=synthetic',
      'currency_code': 'EUR',
      'usd_exchange_rate': 0.01,
      'exchange_rate_date': '2026-11-04',
      'exchange_rate_source': 'frankfurter-v2-blended',
      'usd_total': 0,
    });
    expect(response.isAuthoritativeFor('EUR'), isTrue);
  });
}
