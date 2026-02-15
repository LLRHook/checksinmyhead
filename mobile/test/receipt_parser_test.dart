import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptParser.parseLines', () {
    // =======================================================================
    // Original tests — ensure no regressions
    // =======================================================================

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

    // =======================================================================
    // NEW: Grocery receipt format tests
    // =======================================================================

    test('parses Food Lion receipt with name on separate line + qty format', () {
      // Simulates ML Kit output for the Food Lion receipt
      final lines = [
        'Food Lion #1337 (703) 421-8198',
        '20789 Great Falls Plaza Sterling',
        '',
        'FROZEN/DAIRY',
        'FL PRM ORIG PULP FR W',
        '4 @ 4.49 17.96 A *',
        '',
        'Tax Paid',
        '1.00 Tx 1 17.96 0.18',
        '',
        '4 BALANCE DUE 18.14',
        'VISA \$18.14',
        '',
        'MID: 160000102208',
        'RRN: 530453',
        '',
        'SALE',
        '',
        'XXXXXXXXXXXX9755',
        'VISA Entry Method:Cntctless',
        '',
        '02/06/2026 21:47:46',
        'INVOICE 530453',
        '',
        'Visa Credit',
        'AID: A0000000031010',
        'TVR: 0000000000',
        'TSI: 0000',
        'Total: USD\$ 18.14',
        '',
        'PIN VERIFIED',
        '',
        'CHANGE 0.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Fl Prm Orig Pulp Fr W');
      expect(result.items[0].price, 17.96);
      expect(result.tax, 0.18);
      expect(result.total, 18.14);
    });

    test('handles grocery receipt with tax flags (A, B, F, O)', () {
      final lines = [
        'GREAT VALUE MILK 3.48 O',
        'WHEAT BREAD 2.98 F',
        'COKE 12PK 5.98 A',
        'Subtotal 12.44',
        'Tax 0.36',
        'Total 12.80',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 3);
      expect(result.items[0].name, 'Great Value Milk');
      expect(result.items[0].price, 3.48);
      expect(result.items[1].name, 'Wheat Bread');
      expect(result.items[1].price, 2.98);
      expect(result.items[2].name, 'Coke 12pk');
      expect(result.items[2].price, 5.98);
      expect(result.subtotal, 12.44);
      expect(result.tax, 0.36);
      expect(result.total, 12.80);
    });

    test('handles grocery qty line with separate name line (no total printed)', () {
      final lines = [
        'BANANAS',
        '4 @ 0.25',
        'Subtotal 1.00',
        'Total 1.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Bananas');
      expect(result.items[0].price, 1.00);
    });

    test('handles combined name + qty + price on one line', () {
      final lines = [
        'FL PRM ORIG PULP FR 4 @ 4.49 17.96 A',
        'Subtotal 17.96',
        'Tax 0.18',
        'Total 18.14',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Fl Prm Orig Pulp Fr');
      expect(result.items[0].price, 17.96);
    });

    test('recognizes Tx as tax keyword', () {
      final lines = [
        'MILK 3.48',
        '1.00 Tx 1 3.48 0.21',
        'Total 3.69',
      ];

      final result = ReceiptParser.parseLines(lines);

      // The "1.00 Tx 1 3.48 0.21" line: last price = 0.21, "Tx" matches tax
      expect(result.tax, 0.21);
    });

    test('stops extracting items after payment section', () {
      final lines = [
        'Burger 12.00',
        'Fries 4.00',
        'Subtotal 16.00',
        'Tax 1.36',
        'Total 17.36',
        'VISA \$17.36',
        'Refund Item 5.00', // this should NOT be an item
        'Total: USD\$ 17.36',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Burger');
      expect(result.items[1].name, 'Fries');
    });

    test('filters grocery section headers', () {
      final lines = [
        'FROZEN/DAIRY',
        'Ice Cream 4.99',
        'GROCERY',
        'Cereal 3.49',
        'PRODUCE',
        'Apples 2.99',
        'Subtotal 11.47',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 3);
      expect(result.items[0].name, 'Ice Cream');
      expect(result.items[1].name, 'Cereal');
      expect(result.items[2].name, 'Apples');
    });

    test('rejects currency codes as item names', () {
      final lines = [
        'USD 18.14',
        'Usd 18.14',
        'CAD 25.00',
        'Actual Item 10.00',
        'Subtotal 10.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Actual Item');
    });

    test('handles keyword on previous line (ML Kit split)', () {
      // ML Kit may split "Total" and the dollar amount onto different lines
      final lines = [
        'Sandwich 8.50',
        'Subtotal',
        '\$8.50',
        'Tax',
        '0.72',
        'Total',
        '\$9.22',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Sandwich');
      expect(result.subtotal, 8.50);
      expect(result.tax, 0.72);
      expect(result.total, 9.22);
    });

    test('handles balance due as total keyword', () {
      final lines = [
        'Chicken Wings 15.00',
        '4 BALANCE DUE 15.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.total, 15.00);
    });

    test('filters Tax Paid section header', () {
      final lines = [
        'MILK 3.48',
        'Tax Paid',
        'Subtotal 3.48',
        'Tax 0.21',
        'Total 3.69',
      ];

      final result = ReceiptParser.parseLines(lines);

      // "Tax Paid" should be noise, not affect parsing
      expect(result.items.length, 1);
      expect(result.items[0].name, 'Milk');
      expect(result.tax, 0.21);
    });

    test('handles Walmart-style weight items', () {
      final lines = [
        'BANANAS 2.14 LB @ 0.58/LB 1.24 O',
        'GRAPES 3.22 LB @ 1.99/LB 6.41 O',
        'Subtotal 7.65',
      ];

      // These are tricky — the parser should at least capture them with
      // the correct line total price (last price on the line)
      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      expect(result.items[0].price, 1.24);
      expect(result.items[1].price, 6.41);
    });

    test('filters long digit sequences (barcodes, PINs)', () {
      final lines = [
        'Item One 5.00',
        'PIN:0206133750530223',
        '0206133750530223',
        'Subtotal 5.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Item One');
    });

    test('filters store/register/ticket metadata', () {
      final lines = [
        'Pasta 12.00',
        'STORE:01337 REGISTER:053 CASHIER:0503',
        'TICKET#:0223',
        'Subtotal 12.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
    });

    test('handles receipt with asterisk after tax flag', () {
      final lines = [
        'ORANGE JUICE 4.49 A *',
        'Subtotal 4.49',
        'Tax 0.05',
        'Total 4.54',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Orange Juice');
      expect(result.items[0].price, 4.49);
    });

    test('multiple items with look-back names', () {
      final lines = [
        'COFFEE CREAMER',
        '2 @ 3.99 7.98 A',
        'ORANGE JUICE',
        '4 @ 4.49 17.96 A *',
        'Subtotal 25.94',
        'Tax 0.30',
        'Total 26.24',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Coffee Creamer');
      expect(result.items[0].price, 7.98);
      expect(result.items[1].name, 'Orange Juice');
      expect(result.items[1].price, 17.96);
      expect(result.subtotal, 25.94);
      expect(result.tax, 0.30);
      expect(result.total, 26.24);
    });

    test('handles real-world mixed restaurant receipt', () {
      final lines = [
        'Applebees #1234',
        '01/20/2026 8:15 PM',
        'Server: Mike',
        'Table 7',
        '',
        'Boneless Wings 14.99',
        'Classic Burger 12.49',
        'Lemonade 3.29',
        'Lemonade 3.29',
        '',
        'Subtotal 34.06',
        'Tax 2.90',
        'Tip 6.81',
        'Total 43.77',
        '',
        'Visa xxxx5678',
        'Approved',
        'Thank you!',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 4);
      expect(result.items[0].name, 'Boneless Wings');
      expect(result.items[1].name, 'Classic Burger');
      expect(result.items[2].name, 'Lemonade');
      expect(result.items[3].name, 'Lemonade');
      expect(result.subtotal, 34.06);
      expect(result.tax, 2.90);
      expect(result.tip, 6.81);
      expect(result.total, 43.77);
    });

    test('does not create items from payment section duplicate totals', () {
      final lines = [
        'Milk 3.48',
        'Subtotal 3.48',
        'Tax 0.21',
        'Total 3.69',
        'Visa Credit',
        'AID: A0000000031010',
        'Total: USD\$ 3.69',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Milk');
      // Total should still be captured from the first occurrence
      expect(result.total, 3.69);
    });

    test('handles qty line without pending name (no item created)', () {
      // If ML Kit gives a qty line without a preceding name, skip it
      final lines = [
        '4 @ 4.49 17.96 A *',
        'Subtotal 17.96',
      ];

      final result = ReceiptParser.parseLines(lines);

      // No item because there was no name line before the qty line
      expect(result.items, isEmpty);
      expect(result.subtotal, 17.96);
    });

    test('look-back does not cross noise lines', () {
      final lines = [
        'Some Name',
        'VISA xxxx1234', // noise — should clear pending
        '5.00',
      ];

      final result = ReceiptParser.parseLines(lines);

      // "Some Name" was pending but noise cleared it.
      // "5.00" is standalone price → skipped.
      expect(result.items, isEmpty);
    });

    test('handles Target-style tax category codes after names', () {
      final lines = [
        'ASPIRIN T 4.99',
        'SHAMPOO T 8.49',
        'Subtotal 13.48',
        'Tax 1.15',
        'Total 14.63',
      ];

      final result = ReceiptParser.parseLines(lines);

      expect(result.items.length, 2);
      // Names keep the "T" — acceptable, user can edit in review
      expect(result.items[0].price, 4.99);
      expect(result.items[1].price, 8.49);
    });
  });
}
