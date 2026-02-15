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

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Lightweight DTO for text with bounding-box position.
/// Avoids coupling tests to ML Kit types.
class SpatialTextElement {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const SpatialTextElement({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get centerY => (top + bottom) / 2;
}

/// A single parsed item from a receipt (name + price).
class ParsedItem {
  final String name;
  final double price;

  const ParsedItem({required this.name, required this.price});
}

/// Structured data extracted from a receipt image.
class ParsedReceipt {
  final List<ParsedItem> items;
  final double? subtotal;
  final double? tax;
  final double? tip;
  final double? total;

  const ParsedReceipt({
    required this.items,
    this.subtotal,
    this.tax,
    this.tip,
    this.total,
  });
}

/// Stateless utility that takes ML Kit [RecognizedText] and extracts
/// structured receipt data.
///
/// Parsing strategy:
/// 1. Extract every line of text from the recognized blocks.
/// 2. For each line, look for a price pattern at the end (e.g. `$12.99` or `12.99`).
/// 3. Classify lines with keywords (subtotal, tax, tip, total) as summary fields.
/// 4. Remaining lines with prices are treated as menu items.
/// 5. Filter noise lines (addresses, dates, card info, thank-you messages).
class ReceiptParser {
  // Matches a dollar amount at the end of a line: optional $, digits with optional comma grouping, dot, cents
  static final _priceAtEnd =
      RegExp(r'\$?\s*(-?\d{1,3}(?:,\d{3})*\.\d{2})\s*$');

  // Matches a standalone price line (just a price, nothing else meaningful)
  static final _standalonePriceOnly =
      RegExp(r'^\s*\$?\s*-?\d{1,3}(?:,\d{3})*\.\d{2}\s*$');

  // Keywords that indicate summary/total lines (case insensitive)
  static final _subtotalKeywords = RegExp(
    r'\b(subtotal|sub\s*total|sub\s*ttl|food\s*total|item\s*total)\b',
    caseSensitive: false,
  );
  static final _taxKeywords = RegExp(
    r'\b(tax|sales\s*tax|hst|gst|vat)\b',
    caseSensitive: false,
  );
  static final _tipKeywords = RegExp(
    r'\b(tip|gratuity|grat)\b',
    caseSensitive: false,
  );
  static final _totalKeywords = RegExp(
    r'\b(total|amount\s*due|balance\s*due|grand\s*total|total\s*due)\b',
    caseSensitive: false,
  );

  // Lines to skip entirely (noise)
  static final _noisePatterns = [
    RegExp(r'\b(visa|mastercard|amex|discover|debit|credit)\b', caseSensitive: false),
    RegExp(r'\b(card\s*#|xxxx|approved|auth\s*code|trans\s*id)\b', caseSensitive: false),
    RegExp(r'\b(thank\s*you|come\s*again|welcome)\b', caseSensitive: false),
    RegExp(r'\b(phone|tel|fax|www\.|http)\b', caseSensitive: false),
    RegExp(r'\d{2}[/-]\d{2}[/-]\d{2,4}'), // dates
    RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false), // times
    RegExp(r'^\s*#?\d{3,}[\s-]'), // order/check numbers
    RegExp(r'\b(server|cashier|table|guest|check)\b', caseSensitive: false),
    RegExp(r'\bchange\s*due\b', caseSensitive: false),
    RegExp(r'\btender\b', caseSensitive: false),
    RegExp(r'\bcash\b', caseSensitive: false),
  ];

  // Quantity prefix pattern: "2 x", "2x", "3 @", or bare "2 Tacos"
  // Negative lookahead prevents stripping ordinals like "1st", "2nd", "3rd", "4th"
  static final _qtyPrefix = RegExp(
    r'^(\d+)\s*[x@]\s*|^(\d+)\s+(?!st\b|nd\b|rd\b|th\b)',
    caseSensitive: false,
  );

  /// Parse [RecognizedText] from ML Kit into a [ParsedReceipt].
  static ParsedReceipt parse(RecognizedText recognizedText) {
    final lines = _extractLines(recognizedText);
    return parseLines(lines);
  }

  /// Parse a list of raw text lines into a [ParsedReceipt].
  /// Exposed for unit testing without ML Kit dependency.
  static ParsedReceipt parseLines(List<String> lines) {
    final items = <ParsedItem>[];
    double? subtotal;
    double? tax;
    double? tip;
    double? total;

    for (final line in lines) {
      // Skip noise lines
      if (_isNoise(line)) continue;

      // Try to extract a price from the end of the line
      final priceMatch = _priceAtEnd.firstMatch(line);
      if (priceMatch == null) continue;

      final price =
          double.tryParse(priceMatch.group(1)!.replaceAll(',', ''));
      if (price == null || price == 0) continue;

      // Get the text before the price
      final textBefore = line.substring(0, priceMatch.start).trim();

      // Classify by keyword
      if (_subtotalKeywords.hasMatch(line)) {
        subtotal = price;
      } else if (_taxKeywords.hasMatch(line)) {
        tax = price;
      } else if (_tipKeywords.hasMatch(line)) {
        tip = price;
      } else if (_totalKeywords.hasMatch(line)) {
        total = price;
      } else if (textBefore.isNotEmpty && !_standalonePriceOnly.hasMatch(line)) {
        // It's an item line — clean up the name
        final name = _cleanItemName(textBefore);
        if (name.isNotEmpty && name.length >= 2) {
          items.add(ParsedItem(name: name, price: price));
        }
      }
    }

    // If we found a total but no subtotal, and we have items,
    // try to infer subtotal from items sum
    if (subtotal == null && items.isNotEmpty) {
      final itemsSum = items.fold<double>(0, (sum, i) => sum + i.price);
      // Only set if it looks reasonable (total should be >= items sum)
      if (total == null || (total >= itemsSum - 0.02)) {
        subtotal = itemsSum;
      }
    }

    return ParsedReceipt(
      items: items,
      subtotal: subtotal,
      tax: tax,
      tip: tip,
      total: total,
    );
  }

  /// Extract all text lines from ML Kit's block/line hierarchy.
  static List<String> _extractLines(RecognizedText recognizedText) {
    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }
    return lines;
  }

  /// Returns true if the line matches common receipt noise patterns.
  static bool _isNoise(String line) {
    for (final pattern in _noisePatterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  /// Clean up an item name by removing quantity prefixes and extra whitespace.
  static String _cleanItemName(String raw) {
    var name = raw;

    // Remove quantity prefix (e.g., "2 x " or "3@ ")
    name = name.replaceFirst(_qtyPrefix, '');

    // Remove leading/trailing special characters
    name = name.replaceAll(RegExp(r'^[\s\-*#.]+|[\s\-*#.]+$'), '');

    // Collapse multiple spaces
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Title case if all uppercase
    if (name == name.toUpperCase() && name.length > 1) {
      name = name
          .split(' ')
          .map((w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
    }

    return name.trim();
  }

  // ---------------------------------------------------------------------------
  // Spatial (bounding-box) parsing
  // ---------------------------------------------------------------------------

  /// Parse [RecognizedText] using spatial bounding-box data.
  ///
  /// Converts ML Kit TextLines into [SpatialTextElement]s, groups them into
  /// rows by Y-overlap, reconstructs flat strings per row, and feeds them to
  /// [parseLines]. Falls back to line-based parsing if spatial yields nothing.
  static ParsedReceipt parseSpatial(RecognizedText recognizedText) {
    final elements = <SpatialTextElement>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;
        final text = line.text.trim();
        if (text.isEmpty) continue;
        elements.add(SpatialTextElement(
          text: text,
          left: rect.left,
          top: rect.top,
          right: rect.right,
          bottom: rect.bottom,
        ));
      }
    }

    if (elements.isEmpty) {
      return const ParsedReceipt(items: []);
    }

    final lines = reconstructLines(elements);
    final result = parseLines(lines);

    // Fall back to line-based extraction if spatial yielded nothing
    if (result.items.isEmpty &&
        result.subtotal == null &&
        result.tax == null) {
      final fallbackLines = _extractLines(recognizedText);
      return parseLines(fallbackLines);
    }

    return result;
  }

  /// Group [SpatialTextElement]s into rows based on vertical overlap.
  ///
  /// Two elements are on the same row if the absolute difference between their
  /// Y-centers is within [yTolerance] pixels.
  static List<List<SpatialTextElement>> groupIntoRows(
    List<SpatialTextElement> elements, {
    double yTolerance = 10.0,
  }) {
    if (elements.isEmpty) return [];

    // Sort by top position first
    final sorted = List<SpatialTextElement>.from(elements)
      ..sort((a, b) => a.top.compareTo(b.top));

    final rows = <List<SpatialTextElement>>[];
    var currentRow = <SpatialTextElement>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      // Compare against the average centerY of the current row
      final rowCenterY =
          currentRow.fold<double>(0, (s, e) => s + e.centerY) /
              currentRow.length;

      if ((current.centerY - rowCenterY).abs() <= yTolerance) {
        currentRow.add(current);
      } else {
        rows.add(currentRow);
        currentRow = [current];
      }
    }
    rows.add(currentRow);

    return rows;
  }

  /// Convert grouped spatial rows into flat text strings.
  ///
  /// Within each row, elements are sorted left-to-right and joined with spaces.
  static List<String> reconstructLines(List<SpatialTextElement> elements) {
    final rows = groupIntoRows(elements);
    return rows.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      return row.map((e) => e.text).join(' ');
    }).toList();
  }
}
