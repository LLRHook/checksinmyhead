import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/models/exchange_rate_quote.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> snapshot(BillData bill) => {
  'currency': bill.currencyCode,
  'quote': bill.exchangeRateQuote,
  'loading': bill.isLoadingExchangeRate,
  'error': bill.exchangeRateError,
  'controllers': [
    bill.subtotalController.value,
    bill.taxController.value,
    bill.customTipController.value,
    bill.itemNameController.value,
    bill.itemPriceController.value,
  ],
  'items': bill.items,
  'itemState':
      bill.items.map((i) => [i.name, i.price, Map.of(i.assignments)]).toList(),
  'vendor': bill.scannedVendor,
  'subtotal': bill.subtotal,
  'tax': bill.tax,
  'tip': bill.tipAmount,
  'percentage': bill.tipPercentage,
  'custom': bill.useCustomTipAmount,
  'total': bill.total,
  'itemsTotal': bill.itemsTotal,
  'animated': bill.animatedItemsTotal,
  'birthday': bill.birthdayPerson,
};
BillData existingBill() {
  final bill = BillData()..selectCurrency('EUR');
  bill.setExchangeRateQuote(
    const ExchangeRateQuote(
      currencyCode: 'EUR',
      usdRate: 1.1,
      rateDate: '2026-11-04',
      source: 'frankfurter-v2-blended',
    ),
  );
  bill.subtotalController.value = const TextEditingValue(
    text: '7.250',
    selection: TextSelection.collapsed(offset: 2),
    composing: TextRange(start: 0, end: 1),
  );
  bill.taxController.text = '1.000';
  bill.customTipController.text = '2.00';
  bill.useCustomTipAmount = true;
  bill.calculateBill();
  bill.itemNameController.text = 'Pending';
  bill.itemPriceController.text = '4.00';
  bill.updateItems([
    BillItem(
      name: 'Original',
      price: 7.25,
      assignments: {Person(name: 'Alex', color: Colors.blue): 50},
    ),
  ]);
  bill.updateAnimatedItemsTotal(3);
  bill.scannedVendor = 'Original vendor';
  bill.setExchangeRateLoading();
  return bill;
}

void main() {
  final invalidReceipts = [
    const ParsedReceipt(
      items: [ParsedItem(name: 'New', price: 3, quantity: 501)],
      currencyCode: 'JPY',
      vendor: 'New',
      subtotal: 3,
      tax: 4,
      tip: 5,
    ),
    const ParsedReceipt(
      items: [ParsedItem(name: 'New', price: 3, quantity: 9223372036854775807)],
      currencyCode: 'JPY',
    ),
    const ParsedReceipt(
      items: [
        ParsedItem(name: 'New', price: 3),
        ParsedItem(name: 'New', price: double.nan),
      ],
      currencyCode: 'JPY',
    ),
    ParsedReceipt(items: [], vendor: '🧾' * 256, currencyCode: 'JPY'),
    ParsedReceipt(
      items: [ParsedItem(name: '🧾' * 256, price: 0)],
      currencyCode: 'JPY',
    ),
    const ParsedReceipt(items: [], total: double.infinity, currencyCode: 'JPY'),
    const ParsedReceipt(items: [], currencyCode: 'LONG'),
    const ParsedReceipt(items: [], currencyConfidence: double.nan),
    ParsedReceipt(
      items: List.filled(501, const ParsedItem(name: '', price: 0)),
    ),
  ];
  for (final entry in invalidReceipts.indexed) {
    test(
      'invalid direct candidate ${entry.$1} preserves every value/controller/list/quote and sends no notification',
      () {
        final bill = existingBill();
        addTearDown(bill.dispose);
        final before = snapshot(bill);
        var notifications = 0;
        bill.addListener(() => notifications++);
        expect(
          () => bill.populateFromScan(entry.$2),
          throwsA(isA<ReceiptValidationException>()),
        );
        expect(snapshot(bill), before);
        expect(bill.items, same(before['items']));
        expect(notifications, 0);
      },
    );
  }
  test(
    'valid maximum replacement publishes coherent single notification with original rounding',
    () {
      final bill = existingBill();
      addTearDown(bill.dispose);
      var notifications = 0;
      bill.addListener(() {
        notifications++;
        expect(bill.items.length, 500);
        expect(bill.subtotal, 12);
        expect(bill.tax, 1);
        expect(bill.tipAmount, 2);
        expect(bill.total, 15);
        expect(bill.scannedVendor, 'New');
      });
      bill.populateFromScan(
        const ParsedReceipt(
          vendor: 'New',
          currencyCode: 'jPy',
          subtotal: 12,
          tax: 1,
          tip: 2,
          total: 15,
          items: [
            ParsedItem(name: 'Repeat', price: 13, quantity: 499),
            ParsedItem(name: 'Repeat', price: -1),
          ],
        ),
      );
      expect(bill.currencyCode, 'JPY');
      expect(bill.subtotalController.text, '12.00');
      expect(bill.items.first.price, 0.03);
      expect(bill.items[498].price, -1.94);
      expect(bill.items.last.price, -1);
      expect(bill.itemsTotal, closeTo(12, 1e-9));
      expect(bill.animatedItemsTotal, bill.itemsTotal);
      expect(notifications, 1);
    },
  );
  test(
    'missing summaries retain established defaults, empty items reset item totals, quote policy unchanged',
    () {
      final bill = existingBill();
      addTearDown(bill.dispose);
      final quote = bill.exchangeRateQuote;
      bill.populateFromScan(const ParsedReceipt(items: []));
      expect(bill.items, isEmpty);
      expect(bill.itemsTotal, 0);
      expect(bill.animatedItemsTotal, 0);
      expect(bill.subtotalController.text, '7.250');
      expect(bill.taxController.text, '1.000');
      expect(bill.exchangeRateQuote, same(quote));
      expect(bill.isLoadingExchangeRate, isTrue);
      expect(bill.currencyCode, 'EUR');
    },
  );
  test(
    'quantity rounding discounts duplicates and fallback subtotal preserve original line sums',
    () {
      final bill = BillData();
      addTearDown(bill.dispose);
      bill.populateFromScan(
        const ParsedReceipt(
          items: [
            ParsedItem(name: 'Same', price: 10, quantity: 3),
            ParsedItem(name: 'Same', price: -1, quantity: -5),
          ],
        ),
      );
      expect(bill.items.map((i) => i.price), [3.33, 3.33, 3.34, -1]);
      expect(bill.subtotal, 9);
      expect(bill.total, closeTo(10.62, 1e-10));
    },
  );
}
