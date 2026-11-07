import 'dart:convert';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final invalid = throwsA(isA<ReceiptValidationException>());
  test('bounded preflight depth 16 permits scalar leaves and rejects 17', () {
    var source = '0';
    for (var i = 0; i < 16; i++) {
      source = '{"x":$source}';
    }
    expect(() => ParsedReceipt.decode(source), returnsNormally);
    expect(() => ParsedReceipt.decode('{"x":$source}'), invalid);
  });
  test('bounded preflight counts duplicate keys through 16384 tokens', () {
    final at = '{${List.filled(8191, '"x":0').join(',')}}';
    expect(() => ParsedReceipt.decode(at), returnsNormally);
    expect(() => ParsedReceipt.decode('{"x":0,${at.substring(1)}'), invalid);
  });
  test(
    'every array and every escaped items occurrence is bounded before decode',
    () {
      expect(
        () => ParsedReceipt.decode(
          jsonEncode({'unknown': List.filled(512, null)}),
        ),
        returnsNormally,
      );
      expect(
        () => ParsedReceipt.decode(
          jsonEncode({'unknown': List.filled(513, null)}),
        ),
        invalid,
      );
      expect(
        () => ParsedReceipt.decode(
          '{"i\\u0074ems":${jsonEncode(List.filled(501, null))},"items":[]}',
        ),
        invalid,
      );
      expect(
        () =>
            ParsedReceipt.decode(jsonEncode({'items': List.filled(500, null)})),
        returnsNormally,
      );
      expect(
        () => ParsedReceipt.fromJson({'items': List.filled(501, null)}),
        invalid,
      );
    },
  );
  for (final source in [
    '[]',
    'null',
    '1',
    '"x"',
    '{',
    '{} {}',
    '{"x":[1,]}',
    '{"x":"bad\\q"}',
    '{"x":tru}',
    '{"x":{{}}}',
  ]) {
    test('malformed or non-object document is finite: $source', () {
      expect(() => ParsedReceipt.decode(source), invalid);
    });
  }
  for (final entry
      in <Map<String, dynamic>>[
        {'vendor': 1},
        {'items': {}},
        {
          'items': [true],
        },
        {
          'items': [
            ['x'],
          ],
        },
        {
          'items': [
            {'name': false},
          ],
        },
        {
          'items': [
            {'price': '2'},
          ],
        },
        {
          'items': [
            {'quantity': 1.0},
          ],
        },
        {
          'items': [
            {'quantity': '1'},
          ],
        },
        {
          'items': [
            {'quantity': []},
          ],
        },
        {'tax': {}},
        {'currency_symbol': []},
        {'currency_code': ' EU'},
        {'currency_code': ''},
        {'currency_code': 'ＥＵＲ'},
        {'currency_confidence': '0.5'},
        {'currency_confidence': -0.01},
        {'currency_confidence': 1.01},
        {'total': 1e9 + 1},
      ].indexed) {
    test(
      'malformed typed scalar/container ${entry.$1} stays validation failure',
      () {
        expect(() => ParsedReceipt.fromJson(entry.$2), invalid);
      },
    );
  }
  test(
    'unicode codepoints and money/confidence boundaries have positive controls',
    () {
      final receipt = ParsedReceipt.fromJson({
        'vendor': '🧾' * 255,
        'currency_symbol': '💰' * 16,
        'currency_code': 'jPy',
        'currency_confidence': 1,
        'subtotal': 1e9,
        'tax': -1e9,
        'items': [
          {'name': '🧾' * 255, 'price': -1e9, 'quantity': -9223372036854775808},
        ],
      });
      expect(receipt.expandedItems().single.price, -1e9);
      expect(() => ParsedReceipt.fromJson({'vendor': '🧾' * 256}), invalid);
      expect(
        () => ParsedReceipt.fromJson({'currency_symbol': '💰' * 17}),
        invalid,
      );
      expect(
        () => ParsedReceipt.fromJson({
          'items': [
            {'name': '🧾' * 256},
          ],
        }),
        invalid,
      );
    },
  );
  test(
    'null/default/unknown/empty/zero/negative/repeated values retain compatibility',
    () {
      final receipt = ParsedReceipt.decode(
        '{"vendor":null,"items":[null,{"name":null,"price":null,"quantity":null},{"name":"A","price":-2,"quantity":0},{"name":"A","price":3,"quantity":-4}],"subtotal":null,"currency_code":null,"currency_confidence":null,"unknown":[1,2]}',
      );
      expect(receipt.items.map((i) => i.quantity), [1, 1, 0, -4]);
      expect(receipt.expandedItems().map((i) => i.price), [0, 0, -2, 3]);
      expect(ParsedReceipt.decode('{"items":null}').items, isEmpty);
      expect(ParsedReceipt.decode('{}').items, isEmpty);
    },
  );
  test(
    'checked quantity exact 500, sum excess and maximum integer reject without loops',
    () {
      expect(
        ParsedReceipt.fromJson({
          'items': [
            {'quantity': 500},
          ],
        }).expandedItems().length,
        500,
      );
      for (final items in [
        [const ParsedItem(name: 'a', price: 1, quantity: 501)],
        [const ParsedItem(name: 'a', price: 1, quantity: 9223372036854775807)],
        [
          const ParsedItem(name: 'a', price: 1, quantity: 250),
          const ParsedItem(name: 'a', price: 1, quantity: 251),
        ],
      ]) {
        expect(() => ParsedReceipt(items: items).expandedItems(), invalid);
      }
    },
  );
  for (final number in [double.nan, double.infinity, double.negativeInfinity]) {
    test(
      'direct non-finite $number rejected for all money and confidence slots',
      () {
        for (final receipt in [
          ParsedReceipt(items: [ParsedItem(name: 'a', price: number)]),
          ParsedReceipt(items: [], subtotal: number),
          ParsedReceipt(items: [], tax: number),
          ParsedReceipt(items: [], tip: number),
          ParsedReceipt(items: [], total: number),
          ParsedReceipt(items: [], currencyConfidence: number),
        ]) {
          expect(receipt.validate, invalid);
        }
      },
    );
  }
}
