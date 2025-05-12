import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter tests', () {
    test('formatCurrency formats zero correctly', () {
      expect(CurrencyFormatter.formatCurrency(0), r'$0.00');
    });

    test('formatCurrency formats integer values correctly', () {
      expect(CurrencyFormatter.formatCurrency(1), r'$1.00');
      expect(CurrencyFormatter.formatCurrency(10), r'$10.00');
      expect(CurrencyFormatter.formatCurrency(100), r'$100.00');
      expect(CurrencyFormatter.formatCurrency(1000), r'$1000.00');
    });

    test('formatCurrency formats decimal values correctly', () {
      expect(CurrencyFormatter.formatCurrency(0.5), r'$0.50');
      expect(CurrencyFormatter.formatCurrency(1.23), r'$1.23');
      expect(CurrencyFormatter.formatCurrency(99.99), r'$99.99');
    });

    test('formatCurrency rounds to 2 decimal places', () {
      expect(CurrencyFormatter.formatCurrency(1.234), r'$1.23');
      expect(CurrencyFormatter.formatCurrency(1.235), r'$1.24');
      expect(CurrencyFormatter.formatCurrency(1.999), r'$2.00');
    });

    test('formatCurrency handles negative values', () {
      expect(CurrencyFormatter.formatCurrency(-1.23), r'$-1.23');
    });
  });
}
