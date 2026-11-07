import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reject excessive quantity before parsing can feed review', () {
    expect(
      () => ParsedReceipt.fromJson({
        'items': [
          {'name': 'X', 'price': 2, 'quantity': 501},
        ],
      }),
      throwsA(isA<Exception>()),
    );
  });
  test('reject excessive name rather than build typed graph', () {
    expect(
      () => ParsedReceipt.fromJson({'vendor': '🧾' * 256}),
      throwsA(isA<Exception>()),
    );
  });
  test('malformed scalar is a validation exception rather than TypeError', () {
    expect(
      () => ParsedReceipt.fromJson({'items': 'bad'}),
      throwsA(isA<Exception>()),
    );
  });
  test('invalid direct model leaves entire existing bill unchanged', () {
    final bill = BillData();
    addTearDown(bill.dispose);
    bill.subtotalController.text = '7.25';
    bill.taxController.text = '1.00';
    bill.addItem('Original', 7.25);
    bill.scannedVendor = 'Original';
    final oldItems = bill.items;
    Object? failure;
    try {
      bill.populateFromScan(
        ParsedReceipt(
          currencyCode: 'EUR',
          vendor: 'New',
          subtotal: 2,
          items: [ParsedItem(name: 'New', price: 2, quantity: 501)],
        ),
      );
    } catch (e) {
      failure = e;
    }
    expect(bill.currencyCode, 'USD');
    expect(bill.subtotalController.text, '7.25');
    expect(bill.items, same(oldItems));
    expect(bill.items.single.name, 'Original');
    expect(bill.scannedVendor, 'Original');
    expect(failure, isA<Exception>());
  });
  test('valid nulls discounts duplicates and quantity control', () {
    final bill = BillData();
    addTearDown(bill.dispose);
    bill.populateFromScan(
      ParsedReceipt.fromJson({
        'vendor': null,
        'tax': null,
        'items': [
          {'name': 'Same', 'price': 10, 'quantity': 3},
          {'name': 'Same', 'price': -1, 'quantity': 0},
        ],
      }),
    );
    expect(bill.items.map((i) => i.price), [3.33, 3.33, 3.34, -1]);
    expect(bill.itemsTotal, 9);
  });
}
