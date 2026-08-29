import 'package:checks_frontend/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(request.containsKey('usd_exchange_rate'), isFalse);
      expect(request.containsKey('exchange_rate_date'), isFalse);
      expect(request.containsKey('exchange_rate_source'), isFalse);
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
