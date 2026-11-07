import 'dart:convert';
import 'dart:io';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:flutter/material.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('actual request builder matches backend compatibility fixtures', () {
    final alex = Person(name: 'Alex', color: Colors.blue);
    final sam = Person(name: 'Sam', color: Colors.green);
    final birthday = Person(name: 'Birthday', color: Colors.red);
    Map<String, dynamic> build(
      String name,
      List<BillItem> items,
      Map<Person, double> shares, {
      double subtotal = 100,
      double tax = 10,
      double tip = 18,
      double percentage = 18,
      bool lazy = false,
    }) {
      return ApiService().buildBillRequest(
        billName: name,
        participants: lazy ? [] : [alex, sam, birthday],
        personShares: shares,
        items: items,
        subtotal: subtotal,
        tax: tax,
        tipAmount: tip,
        tipPercentage: percentage,
        total: subtotal + tax + tip,
        paymentMethods: [
          {'name': 'Venmo', 'identifier': '@synthetic'},
        ],
        currencyCode: 'USD',
        lazyMode: lazy,
      );
    }

    final fixtures = <Map<String, dynamic>>[];
    void add(String name, Map<String, dynamic> request) =>
        fixtures.add({'case': name, 'request': request});
    final dinner = [
      BillItem(name: 'Dinner', price: 100, assignments: {alex: 50, sam: 50}),
    ];
    add('normal', build('Dinner', dinner, {alex: 64, sam: 64, birthday: 0}));
    add(
      'custom_tip',
      build('Custom', dinner, {alex: 66, sam: 66, birthday: 0}, tip: 22),
    );
    add(
      'fractional_tip',
      build(
        'Fractional tip',
        dinner,
        {alex: 61.17, sam: 61.18, birthday: 0},
        tip: 12.345,
        percentage: 12.345,
      ),
    );
    add(
      'discount',
      build(
        'Discount',
        [
          BillItem(
            name: 'Dinner',
            price: 100,
            assignments: {alex: 50, sam: 50},
          ),
          BillItem(
            name: 'Discount',
            price: -10,
            assignments: {alex: 50, sam: 50},
          ),
        ],
        {alex: 57.6, sam: 57.6, birthday: 0},
        subtotal: 90,
        tax: 9,
        tip: 16.2,
      ),
    );
    add(
      'fractional',
      build(
        'Fractional',
        [
          BillItem(
            name: 'Repeated',
            price: 1,
            assignments: {alex: 100 / 3, sam: 200 / 3},
          ),
          BillItem(
            name: 'Repeated',
            price: 1,
            assignments: {alex: 50, sam: 50},
          ),
        ],
        {alex: 1.07, sam: 1.49, birthday: 0},
        subtotal: 2,
        tax: .2,
        tip: .36,
        percentage: 18,
      ),
    );
    add(
      'lazy_empty',
      build(
        'Lazy',
        [BillItem(name: 'Dinner', price: 100, assignments: {})],
        {},
        lazy: true,
      ),
    );
    add(
      'lazy_partial',
      build(
        'Partial',
        [
          BillItem(name: 'Dinner', price: 100, assignments: {alex: 25}),
        ],
        {alex: 32},
        lazy: true,
      ),
    );
    for (final withItems in [false, true]) {
      final history = RecentBillModel(
        id: 1,
        billName: 'Saved history',
        participantNames: ['Alex', 'Sam'],
        participantCount: 2,
        total: 128,
        date: DateTime(2025),
        subtotal: 100,
        tax: 10,
        tipAmount: 18,
        color: Colors.blue,
        items:
            withItems
                ? [
                  {'name': 'Dinner', 'price': 100},
                ]
                : null,
      );
      add(
        withItems ? 'history_unassigned' : 'history_no_items',
        ApiService().buildBillRequest(
          billName: history.billName,
          participants: history.participants,
          personShares: history.generatePersonShares(),
          items: history.getBillItems(),
          subtotal: history.subtotal,
          tax: history.tax,
          tipAmount: history.tipAmount,
          tipPercentage: history.tipPercentage,
          total: history.total,
          paymentMethods: [],
          currencyCode: history.currencyCode,
        ),
      );
    }
    final old =
        Map<String, dynamic>.from(fixtures.first['request'] as Map)
          ..remove('currency_code')
          ..remove('display_currency')
          ..remove('lazy_mode');
    add('legacy_usd', old);
    final file = File('test/fixtures/bill_creation_contracts.json');
    if (const bool.fromEnvironment('BILLINGTON_CAPTURE_CONTRACTS')) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(fixtures)}\n',
      );
    }
    expect(
      jsonDecode(file.readAsStringSync()),
      jsonDecode(jsonEncode(fixtures)),
    );
  });

  test(
    'bill upload request sends currency but not authoritative rate fields',
    () {
      final request = ApiService().buildBillRequest(
        billName: 'Dinner',
        participants: const [],
        personShares: const {},
        items: const [],
        subtotal: 10,
        tax: 1,
        tipAmount: 2,
        tipPercentage: 20,
        total: 13,
        paymentMethods: const [],
        currencyCode: 'EUR',
      );

      expect(request['currency_code'], 'EUR');
      expect(request['lazy_mode'], isFalse);
      expect(request.containsKey('usd_exchange_rate'), isFalse);
      expect(request.containsKey('exchange_rate_date'), isFalse);
      expect(request.containsKey('exchange_rate_source'), isFalse);
    },
  );

  test(
    'lazy bill request keeps the bill standalone and flagged as claimable',
    () {
      final request = ApiService().buildBillRequest(
        billName: 'Dinner',
        participants: const [],
        personShares: const {},
        items: const [],
        subtotal: 10,
        tax: 1,
        tipAmount: 2,
        tipPercentage: 20,
        total: 13,
        paymentMethods: const [],
        currencyCode: 'USD',
        lazyMode: true,
      );

      expect(request['lazy_mode'], isTrue);
      expect(request['participants'], isEmpty);
      expect(request['person_shares'], isEmpty);
    },
  );

  test('bill upload response uses authoritative conversion metadata', () {
    final response = BillUploadResponse.fromJson({
      'bill_id': 42,
      'access_token': 'token',
      'share_url': 'https://example.test/b/42',
      'currency_code': 'GBP',
      'usd_exchange_rate': 1.3491,
      'exchange_rate_date': '2026-08-28',
      'exchange_rate_source': 'frankfurter-v2-blended',
      'usd_total': 67.46,
    });

    expect(response.exchangeRateQuote.currencyCode, 'GBP');
    expect(response.exchangeRateQuote.usdRate, 1.3491);
    expect(response.exchangeRateQuote.rateDate, '2026-08-28');
    expect(response.exchangeRateQuote.source, 'frankfurter-v2-blended');
    expect(response.usdTotal, 67.46);
    expect(response.isAuthoritativeFor('GBP'), isTrue);
  });

  test('foreign response rejects missing or mismatched conversion audit', () {
    final missing = BillUploadResponse.fromJson({
      'bill_id': 42,
      'access_token': 'token',
      'share_url': 'https://example.test/b/42',
    });
    final mismatched = BillUploadResponse.fromJson({
      'bill_id': 42,
      'access_token': 'token',
      'share_url': 'https://example.test/b/42',
      'currency_code': 'CAD',
      'usd_exchange_rate': 0.73,
      'exchange_rate_date': '2026-08-29',
      'exchange_rate_source': 'frankfurter-v2-blended',
      'usd_total': 7.30,
    });

    expect(missing.isAuthoritativeFor('EUR'), isFalse);
    expect(mismatched.isAuthoritativeFor('EUR'), isFalse);
  });
}
