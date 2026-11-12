import 'dart:convert';
import 'dart:io';

import 'package:checks_frontend/database/database.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/widgets/bottom_bar.dart';
import 'package:checks_frontend/screens/recent_bills/components/recent_bill_card.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'save_receipt_test.dart' show Harness, alex, birthday, creationResponse;

const pendingForeign = 'Saved on this device. Link and USD conversion pending.';
const pendingNative = 'Saved on this device. Link pending.';
const needsReview =
    'Saved on this device. Publication needs review; no replacement receipt was created.';
const linkReady = 'Saved. Link ready.';
const cardQuotePending = 'USD conversion pending';
const cardRecoveryPending =
    'Saved on this device. Link or trip recovery pending.';

/// One synthetic creation endpoint shared by every app session of a journey.
/// It remembers commits by recovery key, as the maintained server does.
class FakeCreation {
  String mode = 'offline';
  final committed = <String, int>{};
  final bodies = <String>[];
  final keys = <String>[];

  Future<http.Response> call(http.Request request) async {
    final key = request.headers['Idempotency-Key']!;
    bodies.add(request.body);
    keys.add(key);
    if (mode == 'offline') throw const SocketException('synthetic offline');
    if (mode == 'unavailable') return http.Response('{}', 503);
    final id = committed.putIfAbsent(key, () => 19 + committed.length);
    if (mode == 'lost') {
      throw const SocketException('synthetic response lost after commit');
    }
    return http.Response(
      jsonEncode(
        creationResponse(
          jsonDecode(request.body) as Map<String, dynamic>,
          id: id,
          identityVersion: 2,
        ),
      ),
      201,
    );
  }
}

BillSummaryData dinner({String currency = 'EUR'}) => BillSummaryData(
  participants: [alex, birthday],
  birthdayPerson: birthday,
  personShares: {alex: 25, birthday: 0},
  items: [
    BillItem(name: 'Repeated', price: 12, assignments: {alex: 100}),
    BillItem(name: 'Repeated', price: 8, assignments: {alex: 100}),
  ],
  subtotal: 20,
  tax: 2,
  tipAmount: 3,
  total: 25,
  billName: 'Synthetic dinner',
  tipPercentage: 15,
  isCustomTipAmount: true,
  currencyCode: currency,
  paymentMethods: const [
    {'name': 'Synthetic', 'identifier': 'fixture'},
  ],
);

/// Everything the first local transaction wrote about the receipt itself.
Map<String, Object?> nativeFacts(RecentBill row) => {
  'id': row.id,
  'handle': row.creationHandle,
  'key': row.keyLocator,
  'name': row.billName,
  'date': row.date,
  'currency': row.currencyCode,
  'total': row.total,
  'subtotal': row.subtotal,
  'tax': row.tax,
  'tip': row.tipAmount,
  'tipPercentage': row.tipPercentage,
  'items': row.items,
  'participants': row.participants,
  'receiptParticipants': row.receiptParticipants,
  'savedShares': row.savedShares,
  'metadata': row.receiptMetadata,
  'snapshot': row.creationSnapshot,
  'snapshotVersion': row.snapshotVersion,
  'wire': row.creationWireVersion,
};

Map<String, Object?> frozenQuote(RecentBill row) => {
  'remote': row.remoteBillId,
  'url': row.shareUrl,
  'rate': row.usdExchangeRate,
  'date': row.exchangeRateDate,
  'source': row.exchangeRateSource,
  'usd': row.authoritativeUsdTotal,
  'publication': row.publicationState,
  'valuation': row.valuationState,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'one EUR receipt stays one native record across Done, share, retry, restart and trip attachment',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'billington-save-journey-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/synthetic.sqlite');
      final server = FakeCreation();
      Harness open([Harness? previous]) => Harness(
        database: AppDatabase.forTesting(NativeDatabase(file)),
        keyStore: previous?.keys,
      )..onCreate = server.call;

      // Done while offline: one native row, no link and no invented valuation.
      var app = open();
      final done = await app.owner.saveReceipt(
        operationHandle: 'journey',
        receipt: dinner(),
      );
      var row = (await app.db.getRecentBills()).single;
      final facts = nativeFacts(row);
      expect(done.localId, row.id);
      expect(done.message, pendingForeign);
      expect(row.currencyCode, 'EUR');
      expect(row.total, 25);
      expect(row.valuationState, 'pending');
      expect(row.usdExchangeRate, 0);
      expect(row.exchangeRateSource, '');
      expect(row.authoritativeUsdTotal, isNull);
      expect(RecentBillModel.fromData(row).verifiedUsdTotal, isNull);

      Future<void> unchanged(Harness h, {Map<String, Object?>? quote}) async {
        final rows = await h.db.getRecentBills();
        expect(rows, hasLength(1), reason: 'a second local receipt appeared');
        expect(nativeFacts(rows.single), facts);
        if (quote != null) expect(frozenQuote(rows.single), quote);
      }

      // Done again with the same operation while the service is unavailable.
      // A caller that lost the selected currency must not change the receipt.
      server.mode = 'unavailable';
      final again = await app.owner.saveReceipt(
        operationHandle: 'journey',
        receipt: dinner(currency: 'USD'),
      );
      expect(again.localId, done.localId);
      expect(again.message, pendingForeign);
      await unchanged(app);

      // Share (Get Link) reports the same durable state instead of a link.
      await expectLater(
        app.owner.retrySingleBillUpload(done.localId),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            pendingForeign,
          ),
        ),
      );
      await unchanged(app);

      // Restart. Launch recovery reaches the server, which commits, but the
      // response is lost: the row stays pending with the same identity.
      await app.db.close();
      app = open(app);
      server.mode = 'lost';
      await app.owner.retryPendingUploads();
      await unchanged(app);
      row = (await app.db.getRecentBills()).single;
      expect(row.publicationState, 'pending');
      expect(row.publicationAttempted, isTrue);
      expect(row.shareUrl, isNull);
      expect(RecentBillModel.fromData(row).verifiedUsdTotal, isNull);
      expect(server.committed, hasLength(1));

      // Share again: the replay returns the first commit and its frozen quote.
      server.mode = 'ok';
      final url = await app.owner.retrySingleBillUpload(done.localId);
      expect(url, 'https://billington.app/b/19?t=synthetic-source-19');
      row = (await app.db.getRecentBills()).single;
      final quote = frozenQuote(row);
      expect(quote, {
        'remote': 19,
        'url': url,
        'rate': 1.25,
        'date': '2026-11-04',
        'source': 'synthetic-frozen',
        'usd': 31.25,
        'publication': 'published',
        'valuation': 'frozen',
      });
      expect(row.failureCode, isNull);
      expect(SaveReceiptResult.fromRow(row).message, linkReady);
      final model = RecentBillModel.fromData(row);
      expect(model.verifiedUsdTotal, 31.25);
      expect(model.generatePersonShares().map((p, v) => MapEntry(p.name, v)), {
        'Alex': 25,
        'Birthday': 0,
      });
      expect(
        model.generateUSDPersonShares().map((p, v) => MapEntry(p.name, v)),
        {'Alex': 31.25, 'Birthday': 0},
      );
      await unchanged(app, quote: quote);
      final creates = server.bodies.length;

      // Trip attachment uses the same row and never creates another receipt.
      final tab = await app.tab();
      final attached = await app.owner.resumeReceipt(
        done.localId,
        intendedTabId: tab,
      );
      expect(attached.localId, done.localId);
      expect(attached.attachment, AttachmentState.attached);
      expect(attached.message, linkReady);
      expect(app.attachments, 1);
      expect((await app.db.getTabById(tab))!.billIds, '${done.localId}');
      await unchanged(app, quote: quote);

      // Every repeated action is a no-op against the published row.
      expect(
        (await app.owner.saveReceipt(
          operationHandle: 'journey',
          receipt: dinner(currency: 'USD'),
        )).shareUrl,
        url,
      );
      expect(await app.owner.retrySingleBillUpload(done.localId), url);
      await app.owner.resumeReceipt(done.localId, intendedTabId: tab);
      await app.owner.retryPendingUploads();
      expect(app.attachments, 1);
      await unchanged(app, quote: quote);

      // A second restart reads the same record and has nothing left to retry.
      await app.db.close();
      app = open(app);
      addTearDown(app.db.close);
      await app.owner.retryPendingUploads();
      expect(app.requests, isEmpty);
      await unchanged(app, quote: quote);
      expect(
        (await app.db.getRecentBills()).single.attachmentState,
        'attached',
      );

      // One remote receipt, one key, one byte-identical EUR request.
      expect(server.bodies, hasLength(creates));
      expect(server.bodies.toSet(), {facts['snapshot']});
      expect(server.keys.toSet(), hasLength(1));
      expect(server.committed, hasLength(1));
      final sent = jsonDecode(server.bodies.first) as Map<String, dynamic>;
      expect(sent['currency_code'], 'EUR');
      expect(sent['total'], 25);
      expect(app.keys.creates, 1);
    },
  );

  testWidgets(
    'Done failure then Done retry through the actual handler keeps one EUR row and request',
    (tester) async {
      final h = Harness();
      addTearDown(h.db.close);
      final server = FakeCreation()..mode = 'unavailable';
      h.onCreate = server.call;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final presented = <SaveReceiptResult>[];
      Future<SaveReceiptResult?> done(BillSummaryData data) =>
          tester.runAsync<SaveReceiptResult?>(
            () => DoneButtonHandler.handleDone(
              context,
              data: data,
              operationHandle: 'done-retry',
              manager: h.owner,
              confirmName: () async => 'Confirmed EUR',
              presentSaved: (result, _) async => presented.add(result),
              navigateHome: () {},
            ),
          );

      final first = await done(dinner());
      await tester.pumpAndSettle();
      var rows = await tester.runAsync(h.db.getRecentBills);
      expect(rows, hasLength(1));
      expect(first!.localId, rows!.single.id);
      expect(first.failure, SaveFailure.publicationUnavailable);
      expect(presented.single.message, pendingForeign);
      expect(rows.single.currencyCode, 'EUR');
      expect(rows.single.valuationState, 'pending');
      final facts = nativeFacts(rows.single);

      // The retained screen retries with whatever draft it now holds.
      server.mode = 'ok';
      final second = await done(dinner(currency: 'USD'));
      await tester.pumpAndSettle();
      rows = await tester.runAsync(h.db.getRecentBills);
      expect(rows, hasLength(1));
      expect(second!.localId, first.localId);
      expect(nativeFacts(rows!.single), facts);
      expect(presented.last.message, linkReady);
      expect(rows.single.authoritativeUsdTotal, 31.25);
      expect(rows.single.valuationState, 'frozen');
      expect(server.bodies, hasLength(2));
      expect(server.bodies.toSet(), hasLength(1));
      expect(server.keys.toSet(), hasLength(1));
      expect(server.committed, hasLength(1));
      expect(jsonDecode(server.bodies.first)['currency_code'], 'EUR');
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (
      name: 'EUR offline',
      currency: 'EUR',
      status: 0,
      message: pendingForeign,
      valuation: 'pending',
      publication: 'pending',
    ),
    (
      name: 'EUR unavailable',
      currency: 'EUR',
      status: 503,
      message: pendingForeign,
      valuation: 'pending',
      publication: 'pending',
    ),
    (
      name: 'EUR conflict',
      currency: 'EUR',
      status: 409,
      message: needsReview,
      valuation: 'pending',
      publication: 'blocked',
    ),
    (
      name: 'EUR invalid quote',
      currency: 'EUR',
      status: 299,
      message: pendingForeign,
      valuation: 'pending',
      publication: 'pending',
    ),
    (
      name: 'EUR verified',
      currency: 'EUR',
      status: 201,
      message: linkReady,
      valuation: 'frozen',
      publication: 'published',
    ),
    (
      name: 'USD offline',
      currency: 'USD',
      status: 0,
      message: pendingNative,
      valuation: 'native',
      publication: 'pending',
    ),
    (
      name: 'USD unavailable',
      currency: 'USD',
      status: 503,
      message: pendingNative,
      valuation: 'native',
      publication: 'pending',
    ),
    (
      name: 'USD verified',
      currency: 'USD',
      status: 201,
      message: linkReady,
      valuation: 'frozen',
      publication: 'published',
    ),
  ]) {
    testWidgets(
      'quote state ${scenario.name} agrees across the durable row, message and history card',
      (tester) async {
        final h = Harness();
        addTearDown(h.db.close);
        h.onCreate = (request) async {
          if (scenario.status == 0) {
            throw const SocketException('synthetic offline');
          }
          final body = creationResponse(
            jsonDecode(request.body) as Map<String, dynamic>,
            identityVersion: 2,
          );
          // 299 stands for a 201 whose frozen quote is unusable.
          if (scenario.status == 299) body.remove('usd_exchange_rate');
          return http.Response(
            jsonEncode(body),
            scenario.status == 299 ? 201 : scenario.status,
          );
        };
        final result = await tester.runAsync(
          () => h.owner.saveReceipt(
            operationHandle: 'quote-state',
            receipt: dinner(currency: scenario.currency),
          ),
        );
        final row = (await tester.runAsync(h.db.getRecentBills))!.single;
        final durable = SaveReceiptResult.fromRow(row);
        final model = RecentBillModel.fromData(row);
        final verified = scenario.status == 201;

        // The returned result is exactly what a restart would read back.
        expect(result!.publication, durable.publication);
        expect(result.valuation, durable.valuation);
        expect(result.failure, durable.failure);
        expect(result.shareUrl, durable.shareUrl);
        expect(result.message, durable.message);
        expect(row.valuationState, scenario.valuation);
        expect(row.publicationState, scenario.publication);
        expect(row.currencyCode, scenario.currency);
        expect(row.total, 25);
        expect(row.failureCode == null, verified);
        expect(row.shareUrl != null, verified);

        // Message: a conversion is "pending" only while the row says so.
        expect(result.message, scenario.message);
        expect(
          result.message.contains('conversion pending'),
          row.valuationState == 'pending' && row.publicationState == 'pending',
        );
        expect(result.message.contains('Link ready'), row.shareUrl != null);

        // Model: a USD value exists only for native USD or a verified quote.
        final usd =
            scenario.currency == 'USD'
                ? 25.0
                : verified
                ? 31.25
                : null;
        expect(model.verifiedUsdTotal, usd);
        expect(row.authoritativeUsdTotal, verified ? usd : isNull);

        // History card: same state, and never a foreign amount shown as USD.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecentBillCard(
                  bill: model,
                  showBillTotalsInUSD: true,
                  onDeleted: () {},
                  onRefreshNeeded: () {},
                  onRetryUpload: () async => null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(cardQuotePending),
          row.valuationState == 'pending' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(cardRecoveryPending),
          row.failureCode == null ? findsNothing : findsOneWidget,
        );
        expect(
          find.text(
            CurrencyFormatter.formatCurrency(
              usd ?? 25,
              currencyCode: usd == null ? scenario.currency : 'USD',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
