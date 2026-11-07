// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';

/// Finite validation failure, safe to present without retaining receipt content.
class ReceiptValidationException implements Exception {
  const ReceiptValidationException();
  static const message =
      'Receipt data is invalid or too large. Try a clearer photo or enter it manually.';
  @override
  String toString() => message;
}

/// A single parsed item. Price is the whole line, including any quantity.
class ParsedItem {
  final String name;
  final double price;
  final int quantity;

  const ParsedItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory ParsedItem.fromJson(Map<String, dynamic> json) {
    final quantity = json['quantity'];
    if (quantity != null && quantity is! int) {
      throw const ReceiptValidationException();
    }
    final item = ParsedItem(
      name: _text(json['name'], 255) ?? '',
      price: _money(json['price']) ?? 0,
      quantity: quantity as int? ?? 1,
    );
    _validateItem(item);
    return item;
  }
}

/// Receipt validation and quantity expansion have one owner for network,
/// review and direct model callers. No state changes occur here.
class ParsedReceipt {
  static const maxItems = 500;
  final String? vendor;
  final List<ParsedItem> items;
  final double? subtotal;
  final double? tax;
  final double? tip;
  final double? total;
  final String? currencyCode;
  final String? currencySymbol;
  final double? currencyConfidence;

  const ParsedReceipt({
    this.vendor,
    required this.items,
    this.subtotal,
    this.tax,
    this.tip,
    this.total,
    this.currencyCode,
    this.currencySymbol,
    this.currencyConfidence,
  });

  /// Preflight even ignored and duplicate fields before jsonDecode allocates
  /// arbitrary maps/lists. The service separately bounds decoded UTF-8 bytes.
  factory ParsedReceipt.decode(String source) {
    preflightReceiptJson(source);
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic>) {
        throw const ReceiptValidationException();
      }
      return ParsedReceipt.fromJson(json);
    } on FormatException {
      throw const ReceiptValidationException();
    }
  }

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw const ReceiptValidationException();
    }
    if (rawItems is List && rawItems.length > maxItems) {
      throw const ReceiptValidationException();
    }
    final parsedItems = <ParsedItem>[];
    for (final value in (rawItems as List? ?? const [])) {
      // Go's nullable struct entries retain zero/default values.
      if (value != null && value is! Map<String, dynamic>) {
        throw const ReceiptValidationException();
      }
      parsedItems.add(
        ParsedItem.fromJson(value as Map<String, dynamic>? ?? {}),
      );
    }
    final receipt = ParsedReceipt(
      vendor: _text(json['vendor'], 255),
      items: parsedItems,
      subtotal: _money(json['subtotal']),
      tax: _money(json['tax']),
      tip: _money(json['tip']),
      total: _money(json['total']),
      currencyCode: _text(json['currency_code'], 3),
      currencySymbol: _text(json['currency_symbol'], 16),
      currencyConfidence: _number(json['currency_confidence']),
    );
    receipt.validate();
    return receipt;
  }

  /// Validate the entire candidate before review, expansion or bill mutation.
  int validate() {
    _text(vendor, 255);
    _text(currencySymbol, 16);
    if (currencyCode != null &&
        !RegExp(r'^[A-Za-z]{3}$').hasMatch(currencyCode!)) {
      throw const ReceiptValidationException();
    }
    final confidence = currencyConfidence;
    if (confidence != null &&
        (!confidence.isFinite || confidence < 0 || confidence > 1)) {
      throw const ReceiptValidationException();
    }
    for (final value in [subtotal, tax, tip, total]) {
      _money(value);
    }
    if (items.length > maxItems) throw const ReceiptValidationException();
    var count = 0;
    for (final item in items) {
      _validateItem(item);
      final quantity = item.quantity > 1 ? item.quantity : 1;
      // Subtract before adding or looping; even MaxInt cannot overflow this.
      if (quantity > maxItems - count) throw const ReceiptValidationException();
      count += quantity;
    }
    return count;
  }

  /// Preserve the established two-decimal remainder distribution, including JPY.
  List<ParsedItem> expandedItems() {
    validate();
    final expanded = <ParsedItem>[];
    for (final item in items) {
      if (item.quantity > 1) {
        final perUnit = double.parse(
          (item.price / item.quantity).toStringAsFixed(2),
        );
        final lastUnit = double.parse(
          (item.price - perUnit * (item.quantity - 1)).toStringAsFixed(2),
        );
        for (var i = 0; i < item.quantity - 1; i++) {
          expanded.add(ParsedItem(name: item.name, price: perUnit));
        }
        expanded.add(ParsedItem(name: item.name, price: lastUnit));
      } else {
        expanded.add(ParsedItem(name: item.name, price: item.price));
      }
    }
    return expanded;
  }
}

String? _text(Object? value, int limit) {
  if (value == null) return null;
  if (value is! String || value.runes.take(limit + 1).length > limit) {
    throw const ReceiptValidationException();
  }
  return value;
}

double? _number(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw const ReceiptValidationException();
  }
  return value.toDouble();
}

double? _money(Object? value) {
  final number = _number(value);
  if (number != null && number.abs() > 1e9) {
    throw const ReceiptValidationException();
  }
  return number;
}

void _validateItem(ParsedItem item) {
  _text(item.name, 255);
  _money(item.price);
}

/// A bounded lexical walk, not a second DTO decoder. Syntax is checked by
/// jsonDecode afterward. It counts delimiters, keys and scalar values as Go's
/// token walker does, without allocating their complete object graph.
void preflightReceiptJson(String source) => _JsonPreflight(source).check();

class _JsonPreflight {
  final String source;
  int index = 0;
  int tokens = 0;
  _JsonPreflight(this.source);

  Never _invalid() => throw const ReceiptValidationException();
  void _space() {
    while (index < source.length &&
        const [0x20, 0x0a, 0x0d, 0x09].contains(source.codeUnitAt(index))) {
      index++;
    }
  }

  void _token() {
    if (++tokens > 16384) _invalid();
  }

  void check() {
    _value(0, '');
    _space();
    if (index != source.length) _invalid();
  }

  void _value(int depth, String key) {
    _space();
    _token();
    if (index >= source.length) _invalid();
    final char = source[index++];
    if (char == '{' || char == '[') {
      if (depth >= 16) _invalid();
      final object = char == '{';
      final end = object ? '}' : ']';
      final limit = key.toLowerCase() == 'items' ? 500 : 512;
      var count = 0;
      _space();
      if (index < source.length && source[index] == end) {
        index++;
        _token();
        return;
      }
      while (true) {
        var nextKey = '';
        if (object) {
          _space();
          _token();
          if (index >= source.length || source[index++] != '"') _invalid();
          nextKey = _string(key: true);
          _space();
          if (index >= source.length || source[index++] != ':') _invalid();
        } else if (++count > limit) {
          _invalid();
        }
        _value(depth + 1, nextKey);
        _space();
        if (index >= source.length) _invalid();
        final separator = source[index++];
        if (separator == end) {
          _token();
          return;
        }
        if (separator != ',') _invalid();
      }
    } else if (char == '"') {
      _string();
    } else {
      final start = index - 1;
      while (index < source.length &&
          !const [
            ' ',
            '\t',
            '\n',
            '\r',
            ',',
            ']',
            '}',
          ].contains(source[index])) {
        index++;
      }
      if (index == start || const ['}', ']', ',', ':'].contains(char)) {
        _invalid();
      }
    }
  }

  String _string({bool key = false}) {
    final start = index - 1;
    while (index < source.length) {
      final char = source.codeUnitAt(index++);
      if (char == 0x22) {
        // Only short keys can match "items"; huge ignored keys need no copy.
        if (!key || index - start > 32) return '';
        try {
          return jsonDecode(source.substring(start, index)) as String;
        } on FormatException {
          _invalid();
        }
      }
      // Escaped quotes/backslashes cannot end strings.
      if (char == 0x5c) index++;
    }
    _invalid();
  }
}
