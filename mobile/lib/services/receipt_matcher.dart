// Billington: Privacy-first receipt splitting
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

import 'package:checks_frontend/services/mlkit_ocr_service.dart';
import 'package:checks_frontend/services/receipt_parser.dart';

class ReceiptMatcher {
  /// Match parsed items from Claude to OCR lines from ML Kit.
  /// Returns new ParsedItems with boundingBox populated from ML Kit coordinates.
  static List<ParsedItem> matchBoundingBoxes({
    required List<ParsedItem> parsedItems,
    required OcrResult ocrResult,
    required List<String> rawOcrNames,
  }) {
    final imageW = ocrResult.imageSize.width;
    final imageH = ocrResult.imageSize.height;

    final claimed = <int>{};
    final result = <ParsedItem>[];

    for (int i = 0; i < parsedItems.length; i++) {
      final item = parsedItems[i];
      final rawName = i < rawOcrNames.length ? rawOcrNames[i] : '';

      int? bestIdx;
      double bestScore = 0.0;

      for (int j = 0; j < ocrResult.lines.length; j++) {
        if (claimed.contains(j)) continue;

        final ocrText = ocrResult.lines[j].text;
        double score = 0.0;

        // Primary: raw_ocr_name match (best signal from Claude)
        if (rawName.isNotEmpty) {
          score = _similarity(rawName, ocrText);
        }

        // Secondary: cleaned item name match
        final nameScore = _similarity(item.name, ocrText) * 0.8;
        if (nameScore > score) score = nameScore;

        // Bonus: price anchoring
        final priceStr = item.price.toStringAsFixed(2);
        if (ocrText.contains(priceStr)) {
          score += 0.15;
        }

        if (score > bestScore) {
          bestScore = score;
          bestIdx = j;
        }
      }

      BoundingBox? bbox;
      if (bestIdx != null && bestScore >= 0.35) {
        claimed.add(bestIdx);
        final rect = ocrResult.lines[bestIdx].boundingBox;
        bbox = BoundingBox(
          x: rect.left / imageW,
          y: rect.top / imageH,
          width: rect.width / imageW,
          height: rect.height / imageH,
        );
      }

      result.add(ParsedItem(
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        boundingBox: bbox,
      ));
    }

    return result;
  }

  static double _similarity(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na.isEmpty || nb.isEmpty) return 0.0;
    if (na == nb) return 1.0;
    if (nb.contains(na)) return 0.9;
    if (na.contains(nb)) return 0.85;

    final tokensA = na.split(RegExp(r'\s+')).toSet();
    final tokensB = nb.split(RegExp(r'\s+')).toSet();
    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
