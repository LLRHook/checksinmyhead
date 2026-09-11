import 'package:checks_frontend/models/exchange_rate_quote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes and rounds a daily USD conversion quote', () {
    final quote = ExchangeRateQuote.fromJson({
      'date': '2026-08-29',
      'base': 'eur',
      'quote': 'USD',
      'rate': 1.1652,
      'source': 'frankfurter-v2-blended',
    });

    expect(quote.currencyCode, 'EUR');
    expect(quote.isValid, isTrue);
    expect(quote.convertToUSD(19.99), 23.29);
  });

  test('rejects incomplete foreign-currency quotes', () {
    final quote = ExchangeRateQuote.fromJson({'base': 'EUR', 'rate': 1.2});

    expect(quote.isValid, isFalse);
  });
}
