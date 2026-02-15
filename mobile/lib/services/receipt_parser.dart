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
/// 2. For each line, try specialized grocery patterns first (qty × unit = total).
/// 3. Then fall back to price-at-end matching with keyword classification.
/// 4. Use look-back to associate name-only lines with following price lines.
/// 5. Stop extracting items once a payment section is detected.
/// 6. Filter noise lines (addresses, dates, card info, store metadata).
class ReceiptParser {
  // ---------------------------------------------------------------------------
  // Price patterns
  // ---------------------------------------------------------------------------

  /// Price at end of line: optional $, optional negative, comma-grouped digits,
  /// dot, cents. Allows an optional trailing tax-flag letter (A, B, F, T, N, O)
  /// and/or asterisk — common on grocery receipts.
  static final _priceAtEnd = RegExp(
    r'\$?\s*(-?\d{1,3}(?:,\d{3})*\.\d{2})\s*[A-Za-z]?\s*\*?\s*$',
  );

  /// Standalone price-only line (just a dollar amount, nothing else).
  static final _standalonePriceOnly = RegExp(
    r'^\s*\$?\s*-?\d{1,3}(?:,\d{3})*\.\d{2}\s*[A-Za-z]?\s*\*?\s*$',
  );

  /// Grocery qty line: "4 @ 4.49  17.96 A *" — qty, unit price, line total.
  static final _qtyTimesPrice = RegExp(
    r'^\s*(\d+)\s*[x@]\s*\$?\s*(\d+\.\d{2})\s+\$?\s*(\d+\.\d{2})\s*[A-Za-z]?\s*\*?\s*$',
  );

  /// Grocery qty line without a printed total: "4 @ 4.49".
  static final _qtyTimesPriceOnly = RegExp(
    r'^\s*(\d+)\s*[x@]\s*\$?\s*(\d+\.\d{2})\s*$',
  );

  /// Combined name + qty + prices on one line:
  /// "FL PRM ORIG PULP FR W 4 @ 4.49 17.96 A *"
  static final _nameWithQtyPrice = RegExp(
    r'^(.+?)\s+(\d+)\s*[x@]\s*\$?\s*\d+\.\d{2}\s+\$?\s*(\d+\.\d{2})\s*[A-Za-z]?\s*\*?\s*$',
  );

  // ---------------------------------------------------------------------------
  // Summary-line keywords (case-insensitive)
  // ---------------------------------------------------------------------------

  static final _subtotalKeywords = RegExp(
    r'\b(subtotal|sub\s*total|sub\s*ttl|food\s*total|item\s*total)\b',
    caseSensitive: false,
  );
  static final _taxKeywords = RegExp(
    r'\b(tax|sales\s*tax|hst|gst|vat|tx)\b',
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

  // ---------------------------------------------------------------------------
  // Noise patterns — lines to skip entirely
  // ---------------------------------------------------------------------------

  static final _noisePatterns = [
    // Payment cards & processing
    RegExp(r'\b(visa|mastercard|amex|discover|debit|credit)\b',
        caseSensitive: false),
    RegExp(r'\b(card\s*#|xxxx|approved|auth\s*code|trans\s*id)\b',
        caseSensitive: false),
    RegExp(r'\bpin\s*(verified|ok|accepted)?\b', caseSensitive: false),
    RegExp(r'\b(chip|contactless|cntctless|swipe|tap\s+to\s+pay)\b',
        caseSensitive: false),
    RegExp(r'\bentry\s*method\b', caseSensitive: false),
    RegExp(r'\b(mid|aid|tvr|tsi|rrn|arn)\s*:', caseSensitive: false),
    // Courtesy messages
    RegExp(r'\b(thank\s*you|come\s*again|welcome)\b', caseSensitive: false),
    // Contact / web / surveys
    RegExp(r'\b(phone|tel|fax|www\.|http)\b', caseSensitive: false),
    RegExp(r'\b(survey|opinion|feedback)\b', caseSensitive: false),
    RegExp(r'\bcustomer\s*service\b', caseSensitive: false),
    // Dates and times
    RegExp(r'\d{2}[/-]\d{2}[/-]\d{2,4}'),
    RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false),
    // Staff / table / metadata
    RegExp(r'\b(server|cashier|table|guest|check)\b', caseSensitive: false),
    RegExp(r'\b(store|register|ticket)\s*[:#]', caseSensitive: false),
    RegExp(r'\binvoice\b', caseSensitive: false),
    // Order / receipt numbers (3+ digits at start of line)
    RegExp(r'^\s*#?\d{3,}[\s-]'),
    // Change / tender / cash
    RegExp(r'\bchange\b', caseSensitive: false),
    RegExp(r'\btender\b', caseSensitive: false),
    RegExp(r'\bcash\b', caseSensitive: false),
    // "Tax Paid" is a section header, not a tax line
    RegExp(r'^\s*tax\s*paid\s*$', caseSensitive: false),
    // Grocery section headers with slash: "FROZEN/DAIRY", "HEALTH/BEAUTY"
    RegExp(r'^\s*[A-Z]{3,}/[A-Z]{3,}\s*$'),
    // Standalone currency codes
    RegExp(r'^\s*\$?\s*(usd|cad|eur|gbp)\$?\s*$', caseSensitive: false),
    // Long digit sequences (barcodes, PINs)
    RegExp(r'^\s*(pin\s*:?\s*)?\d{10,}\s*$', caseSensitive: false),
    // Non-English common lines
    RegExp(r'\btambi[eé]n\b', caseSensitive: false),
    // "SALE" standalone
    RegExp(r'^\s*sale\s*$', caseSensitive: false),
  ];

  // ---------------------------------------------------------------------------
  // Payment section markers — once seen, stop extracting items
  // ---------------------------------------------------------------------------

  static final _paymentSectionMarkers = [
    RegExp(r'\b(visa|mastercard|amex|discover)\s*(credit|debit)?\b',
        caseSensitive: false),
    RegExp(r'^\s*sale\s*$', caseSensitive: false),
    RegExp(r'\bpin\s*verified\b', caseSensitive: false),
    RegExp(r'\bapproved\b', caseSensitive: false),
    RegExp(r'\b(mid|aid)\s*:', caseSensitive: false),
  ];

  // ---------------------------------------------------------------------------
  // Item-name cleaning
  // ---------------------------------------------------------------------------

  /// Quantity prefix: "2 x", "2x", "3 @", or bare "2 Tacos".
  /// Negative lookahead prevents stripping ordinals like "1st", "2nd".
  static final _qtyPrefix = RegExp(
    r'^(\d+)\s*[x@]\s*|^(\d+)\s+(?!st\b|nd\b|rd\b|th\b)',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

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
    bool inPaymentSection = false;
    // Look-back: stores the previous non-price, non-noise line so we can
    // associate an item name with a price that appears on the next line.
    String? pendingName;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect payment section entry
      if (!inPaymentSection && _isPaymentSectionMarker(line)) {
        inPaymentSection = true;
      }

      // Skip noise
      if (_isNoise(line)) {
        pendingName = null;
        continue;
      }

      // ---------------------------------------------------------------
      // 1. Combined name + qty line: "ITEM NAME 4 @ 4.49 17.96 A *"
      // ---------------------------------------------------------------
      final nameQtyMatch = _nameWithQtyPrice.firstMatch(line);
      if (nameQtyMatch != null && !inPaymentSection) {
        final lineTotal = double.tryParse(nameQtyMatch.group(3)!);
        if (lineTotal != null && lineTotal > 0) {
          final name = _cleanItemName(nameQtyMatch.group(1)!.trim());
          if (name.isNotEmpty && name.length >= 2) {
            items.add(ParsedItem(name: name, price: lineTotal));
          }
          pendingName = null;
          continue;
        }
      }

      // ---------------------------------------------------------------
      // 2. Qty line with total: "4 @ 4.49  17.96 A *"
      //    Item name comes from the previous line (look-back).
      // ---------------------------------------------------------------
      final qtyMatch = _qtyTimesPrice.firstMatch(line);
      if (qtyMatch != null) {
        if (!inPaymentSection) {
          final lineTotal = double.tryParse(qtyMatch.group(3)!);
          if (lineTotal != null && lineTotal > 0 && pendingName != null) {
            final name = _cleanItemName(pendingName);
            if (name.isNotEmpty && name.length >= 2) {
              items.add(ParsedItem(name: name, price: lineTotal));
            }
          }
        }
        pendingName = null;
        continue;
      }

      // ---------------------------------------------------------------
      // 3. Qty line without total: "4 @ 4.49" — calculate total.
      // ---------------------------------------------------------------
      final qtyOnlyMatch = _qtyTimesPriceOnly.firstMatch(line);
      if (qtyOnlyMatch != null) {
        if (!inPaymentSection) {
          final qty = int.tryParse(qtyOnlyMatch.group(1)!) ?? 1;
          final unit = double.tryParse(qtyOnlyMatch.group(2)!);
          if (unit != null && unit > 0 && pendingName != null) {
            final lineTotal =
                double.parse((qty * unit).toStringAsFixed(2));
            final name = _cleanItemName(pendingName);
            if (name.isNotEmpty && name.length >= 2) {
              items.add(ParsedItem(name: name, price: lineTotal));
            }
          }
        }
        pendingName = null;
        continue;
      }

      // ---------------------------------------------------------------
      // 4. Standard price-at-end matching
      // ---------------------------------------------------------------
      final priceMatch = _priceAtEnd.firstMatch(line);
      if (priceMatch == null) {
        // No price — store as potential item name for next line
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && _looksLikeItemName(trimmed)) {
          pendingName = trimmed;
        } else {
          pendingName = null;
        }
        continue;
      }

      final price =
          double.tryParse(priceMatch.group(1)!.replaceAll(',', ''));
      if (price == null || price == 0) {
        pendingName = null;
        continue;
      }

      final textBefore = line.substring(0, priceMatch.start).trim();

      // ---------------------------------------------------------------
      // 5. Keyword classification (works even in payment section so we
      //    don't miss a total/tax printed after the card info).
      // ---------------------------------------------------------------

      // First check if this line itself has keywords
      if (_subtotalKeywords.hasMatch(line)) {
        subtotal = price;
        pendingName = null;
        continue;
      }
      if (_taxKeywords.hasMatch(line)) {
        tax = price;
        pendingName = null;
        continue;
      }
      if (_tipKeywords.hasMatch(line)) {
        tip = price;
        pendingName = null;
        continue;
      }
      if (_totalKeywords.hasMatch(line)) {
        total = price;
        pendingName = null;
        continue;
      }

      // Check if pendingName (previous line) had a keyword — this handles
      // ML Kit splitting "Subtotal" and "$12.99" onto separate lines.
      if (pendingName != null && _classifyFromPending(pendingName)) {
        if (_subtotalKeywords.hasMatch(pendingName)) {
          subtotal = price;
        } else if (_taxKeywords.hasMatch(pendingName)) {
          tax = price;
        } else if (_tipKeywords.hasMatch(pendingName)) {
          tip = price;
        } else if (_totalKeywords.hasMatch(pendingName)) {
          total = price;
        }
        pendingName = null;
        continue;
      }

      // ---------------------------------------------------------------
      // 6. Item extraction (only before payment section)
      // ---------------------------------------------------------------
      if (!inPaymentSection) {
        String? itemName;

        // First try: use text before the price on this line
        if (textBefore.isNotEmpty &&
            !_standalonePriceOnly.hasMatch(line) &&
            _looksLikeItemName(textBefore)) {
          itemName = textBefore;
        }

        // Second try: look-back to previous line
        if (itemName == null && pendingName != null) {
          itemName = pendingName;
        }

        if (itemName != null) {
          final name = _cleanItemName(itemName);
          if (name.isNotEmpty && name.length >= 2) {
            items.add(ParsedItem(name: name, price: price));
          }
        }
      }

      pendingName = null;
    }

    // Infer subtotal from item sum when not explicitly found
    if (subtotal == null && items.isNotEmpty) {
      final itemsSum = items.fold<double>(0, (sum, i) => sum + i.price);
      // Only set if it looks reasonable (total should be >= items sum)
      if (total == null || (total >= itemsSum - 0.02)) {
        subtotal = double.parse(itemsSum.toStringAsFixed(2));
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extract all text lines from ML Kit's block → line hierarchy.
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

  /// Returns `true` if [line] matches any noise pattern.
  static bool _isNoise(String line) {
    for (final pattern in _noisePatterns) {
      if (pattern.hasMatch(line)) return true;
    }
    return false;
  }

  /// Returns `true` if [line] signals the start of the payment section.
  static bool _isPaymentSectionMarker(String line) {
    for (final marker in _paymentSectionMarkers) {
      if (marker.hasMatch(line)) return true;
    }
    return false;
  }

  /// Returns `true` if [pendingName] contains a summary keyword.
  static bool _classifyFromPending(String pending) {
    return _subtotalKeywords.hasMatch(pending) ||
        _taxKeywords.hasMatch(pending) ||
        _tipKeywords.hasMatch(pending) ||
        _totalKeywords.hasMatch(pending);
  }

  /// Returns `true` if [text] looks like a plausible item name rather than
  /// a stray number, currency code, or price fragment.
  static bool _looksLikeItemName(String text) {
    // Must contain at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(text)) return false;
    // Reject standalone currency codes (USD, CAD, EUR, GBP)
    if (RegExp(r'^\s*(usd|cad|eur|gbp)\$?\s*$', caseSensitive: false)
        .hasMatch(text)) {
      return false;
    }
    // Reject if it's just a dollar amount
    if (RegExp(r'^\s*\$\s*\d+\.?\d*\s*$').hasMatch(text)) return false;
    return true;
  }

  /// Clean an item name: strip qty prefixes, special chars, collapse spaces,
  /// and title-case ALL-CAPS text.
  static String _cleanItemName(String raw) {
    var name = raw;

    // Remove quantity prefix (e.g., "2 x " or "3@ " or bare "2 ")
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
