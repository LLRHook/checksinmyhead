import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.formatCurrency', () {
    test('formats whole dollar amount', () {
      expect(CurrencyFormatter.formatCurrency(100.0), equals('\$100.00'));
    });

    test('formats amount with cents', () {
      expect(CurrencyFormatter.formatCurrency(42.5), equals('\$42.50'));
    });

    test('formats zero', () {
      expect(CurrencyFormatter.formatCurrency(0.0), equals('\$0.00'));
    });

    test('formats penny', () {
      expect(CurrencyFormatter.formatCurrency(0.01), equals('\$0.01'));
    });

    test('rounds correctly', () {
      expect(CurrencyFormatter.formatCurrency(9.999), equals('\$10.00'));
    });

    test('formats large amount', () {
      expect(CurrencyFormatter.formatCurrency(1234.56), equals('\$1234.56'));
    });
  });
}
