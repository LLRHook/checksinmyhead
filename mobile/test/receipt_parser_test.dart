import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptParser.parseLines', () {
    test('parses a standard restaurant receipt', () {
      final lines = [
        'Joes Burger Shack',
        '123 Main St, Anytown',
        '',
        'Cheeseburger              12.99',
        'Fries                      4.99',
        'Iced Tea                   2.50',
        '',
        'Subtotal                  20.48',
        'Tax                        1.74',
        'Tip                        4.00',
        'Total                     26.22',
        '',
        'VISA xxxx1234',
        'Thank you!',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 3);
      expect(result.items[0].name, 'Cheeseburger');
      expect(result.items[0].price, 12.99);
      expect(result.items[1].name, 'Fries');
      expect(result.items[1].price, 4.99);
      expect(result.items[2].name, 'Iced Tea');
      expect(result.items[2].price, 2.50);
      expect(result.subtotal, 20.48);
      expect(result.tax, 1.74);
      expect(result.tip, 4.00);
      expect(result.total, 26.22);
    });

    test('parses receipt with dollar signs', () {
      final lines = [
        'Pasta \$14.50',
        'Salad \$8.99',
        'Subtotal \$23.49',
        'Tax \$2.00',
        'Total \$25.49',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Pasta');
      expect(result.items[0].price, 14.50);
      expect(result.items[1].name, 'Salad');
      expect(result.items[1].price, 8.99);
      expect(result.subtotal, 23.49);
      expect(result.tax, 2.00);
      expect(result.total, 25.49);
    });

    test('handles receipt without tip', () {
      final lines = [
        'Coffee 4.50',
        'Muffin 3.25',
        'Sub Total 7.75',
        'Sales Tax 0.66',
        'Total 8.41',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      expect(result.subtotal, 7.75);
      expect(result.tax, 0.66);
      expect(result.tip, isNull);
      expect(result.total, 8.41);
    });

    test('handles receipt without subtotal (infers from items)', () {
      final lines = [
        'Wings 10.00',
        'Beer 6.00',
        'Tax 1.36',
        'Total 17.36',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      expect(result.subtotal, 16.00); // inferred from items
      expect(result.tax, 1.36);
    });

    test('filters noise lines', () {
      final lines = [
        '01/15/2025 7:30 PM',
        'Server: John',
        'Table 12',
        'Burger 15.00',
        'Visa xxxx4567',
        'Auth Code: 123456',
        'Thank you for dining!',
        'www.joesplace.com',
        'Subtotal 15.00',
        'Total 15.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Burger');
    });

    test('handles quantity prefix lines', () {
      final lines = [
        '2 x Tacos 8.00',
        '3@ Drinks 12.00',
        'Subtotal 20.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Tacos');
      expect(result.items[0].price, 8.00);
      expect(result.items[1].name, 'Drinks');
    });

    test('converts ALL-CAPS item names to title case', () {
      final lines = [
        'MARGHERITA PIZZA 16.00',
        'CAESAR SALAD 12.00',
        'Subtotal 28.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items[0].name, 'Margherita Pizza');
      expect(result.items[1].name, 'Caesar Salad');
    });

    test('skips standalone price-only lines', () {
      final lines = [
        '12.99',
        '\$8.50',
        'Actual Item 10.00',
        'Subtotal 10.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Actual Item');
    });

    test('handles empty input', () {
      final result = ReceiptParser.parseLines([]);

      expect(result.items, isEmpty);
      expect(result.subtotal, isNull);
      expect(result.tax, isNull);
      expect(result.tip, isNull);
      expect(result.total, isNull);
    });

    test('handles lines with no prices', () {
      final lines = [
        'Restaurant Name',
        'Address line 1',
        'No prices here',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items, isEmpty);
    });

    test('recognizes gratuity as tip', () {
      final lines = [
        'Pizza 20.00',
        'Subtotal 20.00',
        'Tax 1.70',
        'Gratuity 4.00',
        'Total 25.70',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.tip, 4.00);
    });

    test('recognizes HST/GST as tax', () {
      final lines = [
        'Poutine 12.00',
        'Subtotal 12.00',
        'HST 1.56',
        'Total 13.56',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.tax, 1.56);
    });

    test('recognizes amount due as total', () {
      final lines = [
        'Steak 35.00',
        'Subtotal 35.00',
        'Tax 2.98',
        'Amount Due 37.98',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.total, 37.98);
    });

    test('rejects items with very short names', () {
      final lines = [
        'A 5.00', // too short — single char
        'OK 7.00', // 2 chars — accepted
        'Burger 12.00',
        'Subtotal 24.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      // "A" is rejected (< 2 chars), "OK" and "Burger" are kept
      expect(result.items.length, 2);
      expect(result.items[0].name, 'Ok');
      expect(result.items[1].name, 'Burger');
    });
  });
}
