import 'package:checks_frontend/models/exchange_rate_quote.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('USD is immediately ready without a network quote', () {
    final data = BillData();
    addTearDown(data.dispose);

    expect(data.currencyCode, 'USD');
    expect(data.hasUsableExchangeRate, isTrue);
    expect(data.exchangeRateQuote.usdRate, 1);
  });

  test('foreign currency blocks until a matching quote is available', () {
    final data = BillData();
    addTearDown(data.dispose);

    data.selectCurrency('EUR');
    expect(data.hasUsableExchangeRate, isFalse);

    data.setExchangeRateQuote(
      const ExchangeRateQuote(
        currencyCode: 'EUR',
        usdRate: 1.2,
        rateDate: '2026-08-29',
        source: 'frankfurter-v2-blended',
      ),
    );
    data.subtotalController.text = '10.00';

    expect(data.hasUsableExchangeRate, isTrue);
    expect(data.usdTotal, 14.16);
  });

  test('failed quote stays explicit and blocks continuation', () {
    final data = BillData();
    addTearDown(data.dispose);

    data.selectCurrency('GBP');
    data.setExchangeRateError('Daily rate unavailable');

    expect(data.hasUsableExchangeRate, isFalse);
    expect(data.exchangeRateError, 'Daily rate unavailable');
  });
}
