import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParsedReceipt.fromJson', () {
    test('parses a complete receipt response', () {
      final json = {
        'vendor': 'Walmart',
        'items': [
          {'name': 'Milk', 'price': 3.99, 'quantity': 1},
          {'name': 'Bread', 'price': 2.49, 'quantity': 2},
        ],
        'subtotal': 8.97,
        'tax': 0.72,
        'tip': 0.0,
        'total': 9.69,
      };

      final receipt = ParsedReceipt.fromJson(json);

      expect(receipt.vendor, 'Walmart');
      expect(receipt.items.length, 2);
      expect(receipt.items[0].name, 'Milk');
      expect(receipt.items[0].price, 3.99);
      expect(receipt.items[0].quantity, 1);
      expect(receipt.items[1].name, 'Bread');
      expect(receipt.items[1].price, 2.49);
      expect(receipt.items[1].quantity, 2);
      expect(receipt.subtotal, 8.97);
      expect(receipt.tax, 0.72);
      expect(receipt.tip, 0.0);
      expect(receipt.total, 9.69);
    });

    test('handles missing optional fields', () {
      final json = {
        'items': [
          {'name': 'Coffee', 'price': 4.50},
        ],
      };

      final receipt = ParsedReceipt.fromJson(json);

      expect(receipt.vendor, isNull);
      expect(receipt.items.length, 1);
      expect(receipt.items[0].name, 'Coffee');
      expect(receipt.items[0].price, 4.50);
      expect(receipt.items[0].quantity, 1); // default
      expect(receipt.subtotal, isNull);
      expect(receipt.tax, isNull);
      expect(receipt.tip, isNull);
      expect(receipt.total, isNull);
    });

    test('handles empty items list', () {
      final json = {
        'vendor': 'Unknown Store',
        'items': <Map<String, dynamic>>[],
        'total': 5.00,
      };

      final receipt = ParsedReceipt.fromJson(json);

      expect(receipt.items, isEmpty);
      expect(receipt.total, 5.00);
    });

    test('handles null items', () {
      final json = {
        'vendor': 'Unknown Store',
        'total': 5.00,
      };

      final receipt = ParsedReceipt.fromJson(json);

      expect(receipt.items, isEmpty);
    });

    test('handles negative prices (discounts)', () {
      final json = {
        'items': [
          {'name': 'Burger', 'price': 12.99},
          {'name': 'Coupon Discount', 'price': -3.00},
        ],
        'total': 9.99,
      };

      final receipt = ParsedReceipt.fromJson(json);

      expect(receipt.items.length, 2);
      expect(receipt.items[1].price, -3.00);
    });

    test('handles integer prices as doubles', () {
      final json = {
        'items': [
          {'name': 'Item', 'price': 10},
        ],
        'subtotal': 10,
        'tax': 1,
        'total': 11,
      };

      final receipt = ParsedReceipt.fromJson(json);

      expect(receipt.items[0].price, 10.0);
      expect(receipt.subtotal, 10.0);
      expect(receipt.tax, 1.0);
      expect(receipt.total, 11.0);
    });
  });

  group('ParsedItem.fromJson', () {
    test('parses with all fields', () {
      final json = {'name': 'Soda', 'price': 1.99, 'quantity': 3};
      final item = ParsedItem.fromJson(json);

      expect(item.name, 'Soda');
      expect(item.price, 1.99);
      expect(item.quantity, 3);
    });

    test('defaults quantity to 1', () {
      final json = {'name': 'Soda', 'price': 1.99};
      final item = ParsedItem.fromJson(json);

      expect(item.quantity, 1);
    });

    test('handles missing fields gracefully', () {
      final json = <String, dynamic>{};
      final item = ParsedItem.fromJson(json);

      expect(item.name, '');
      expect(item.price, 0.0);
      expect(item.quantity, 1);
    });
  });
}
