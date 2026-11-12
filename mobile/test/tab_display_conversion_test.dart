import 'dart:convert';

import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:checks_frontend/screens/tabs/tab_manager.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'trip display conversion is live, reports an outage and never rewrites the stored receipt',
    (tester) async {
      final h = Harness();
      addTearDown(h.db.close);
      // One published EUR 25.00 receipt frozen at USD 31.25.
      final saved = (await tester.runAsync(h.save))!;
      final tabs = TabManager.withDependencies(
        database: h.db,
        receipts: h.owner,
      );
      addTearDown(tabs.dispose);
      final tabId =
          (await tester.runAsync(
            () => h.db.insertTab(
              TabsCompanion(
                name: const Value('Synthetic local trip'),
                billIds: Value('${saved.localId}'),
              ),
            ),
          ))!;
      await tester.runAsync(
        () => PreferencesService().setTabDisplayCurrency(tabId, 'PEN'),
      );
      final tab = (await tester.runAsync(() => tabs.getTabById(tabId)))!;
      expect(tab.displayCurrency, 'PEN');
      final stored =
          (await tester.runAsync(
            () => h.db.getBillById(saved.localId),
          ))!.toJson();
      expect(stored['currencyCode'], 'EUR');
      expect(stored['total'], 25);
      expect(stored['usdExchangeRate'], 1.25);
      expect(stored['authoritativeUsdTotal'], 31.25);

      var available = true;
      double rate = 4;
      final pairs = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/currency/rate');
          pairs.add(
            '${request.url.queryParameters['from']}/${request.url.queryParameters['to']}',
          );
          return available
              ? http.Response(
                jsonEncode({
                  'from': 'USD',
                  'to': 'PEN',
                  'rate': rate,
                  'source': 'frankfurter-v2-blended',
                  'updated_at': '2026-11-09T00:00:00Z',
                }),
                200,
              )
              : http.Response('{}', 503);
        }),
        baseUrl: 'https://synthetic.invalid',
      );
      Future<void> open(int visit) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TabDetailScreen(
              key: ValueKey(visit),
              tab: tab,
              tabManager: tabs,
              billsManager: h.owner,
              apiService: api,
              database: h.db,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }

      // Live rate: the frozen USD 31.25 is shown as PEN at today's rate.
      await open(1);
      expect(find.text('PEN 125.00'), findsWidgets);
      expect(find.textContaining('conversion unavailable'), findsNothing);

      // The market moves: the next visit shows the new rate, nothing is cached.
      rate = 3.2;
      await open(2);
      expect(find.text('PEN 100.00'), findsWidgets);
      expect(find.text('PEN 125.00'), findsNothing);

      // Outage: no amount is shown under the PEN label, and none as USD.
      available = false;
      await open(3);
      expect(find.text('PEN conversion unavailable'), findsWidgets);
      expect(find.textContaining('PEN 1'), findsNothing);
      expect(find.textContaining('31.25'), findsNothing);

      expect(pairs, ['USD/PEN', 'USD/PEN', 'USD/PEN']);
      expect(
        (await tester.runAsync(
          () => h.db.getBillById(saved.localId),
        ))!.toJson(),
        stored,
      );
      expect(await tester.runAsync(h.db.getRecentBills), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
