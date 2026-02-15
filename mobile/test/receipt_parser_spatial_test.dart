import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptParser.groupIntoRows', () {
    test('groups elements on the same Y-line into one row', () {
      final elements = [
        const SpatialTextElement(
            text: 'Burger', left: 10, top: 100, right: 150, bottom: 120),
        const SpatialTextElement(
            text: '12.99', left: 300, top: 102, right: 380, bottom: 118),
      ];

      final rows = ReceiptParser.groupIntoRows(elements);

      expect(rows.length, 1);
      expect(rows[0].length, 2);
    });

    test('separates elements on different Y-lines into separate rows', () {
      final elements = [
        const SpatialTextElement(
            text: 'Burger', left: 10, top: 100, right: 150, bottom: 120),
        const SpatialTextElement(
            text: '12.99', left: 300, top: 102, right: 380, bottom: 118),
        const SpatialTextElement(
            text: 'Fries', left: 10, top: 200, right: 120, bottom: 220),
        const SpatialTextElement(
            text: '4.99', left: 300, top: 201, right: 370, bottom: 219),
      ];

      final rows = ReceiptParser.groupIntoRows(elements);

      expect(rows.length, 2);
      expect(rows[0].length, 2);
      expect(rows[1].length, 2);
    });

    test('returns empty list for empty input', () {
      final rows = ReceiptParser.groupIntoRows([]);

      expect(rows, isEmpty);
    });

    test('handles single-element rows', () {
      final elements = [
        const SpatialTextElement(
            text: 'Restaurant Name', left: 50, top: 10, right: 300, bottom: 30),
        const SpatialTextElement(
            text: 'Burger 12.99', left: 10, top: 100, right: 380, bottom: 120),
      ];

      final rows = ReceiptParser.groupIntoRows(elements);

      expect(rows.length, 2);
      expect(rows[0].length, 1);
      expect(rows[1].length, 1);
    });
  });

  group('ReceiptParser.reconstructLines', () {
    test('joins same-row elements left-to-right with spaces', () {
      final elements = [
        // Price is left of name in the list, but right on screen
        const SpatialTextElement(
            text: '12.99', left: 300, top: 100, right: 380, bottom: 120),
        const SpatialTextElement(
            text: 'Burger', left: 10, top: 102, right: 150, bottom: 118),
      ];

      final lines = ReceiptParser.reconstructLines(elements);

      expect(lines.length, 1);
      expect(lines[0], 'Burger 12.99');
    });

    test('produces one line per row, sorted by Y then X', () {
      final elements = [
        const SpatialTextElement(
            text: 'Fries', left: 10, top: 200, right: 120, bottom: 220),
        const SpatialTextElement(
            text: '4.99', left: 300, top: 201, right: 370, bottom: 219),
        const SpatialTextElement(
            text: 'Burger', left: 10, top: 100, right: 150, bottom: 120),
        const SpatialTextElement(
            text: '12.99', left: 300, top: 102, right: 380, bottom: 118),
      ];

      final lines = ReceiptParser.reconstructLines(elements);

      expect(lines.length, 2);
      expect(lines[0], 'Burger 12.99');
      expect(lines[1], 'Fries 4.99');
    });
  });

  group('Spatial end-to-end via reconstructLines + parseLines', () {
    test('parses spatially separated name and price on same row', () {
      final elements = [
        const SpatialTextElement(
            text: 'Cheeseburger', left: 10, top: 100, right: 200, bottom: 120),
        const SpatialTextElement(
            text: '12.99', left: 300, top: 101, right: 380, bottom: 119),
        const SpatialTextElement(
            text: 'Subtotal', left: 10, top: 200, right: 150, bottom: 220),
        const SpatialTextElement(
            text: '12.99', left: 300, top: 201, right: 380, bottom: 219),
      ];

      final lines = ReceiptParser.reconstructLines(elements);
      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Cheeseburger');
      expect(result.items[0].price, 12.99);
      expect(result.subtotal, 12.99);
    });
  });
}
