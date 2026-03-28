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

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A text line detected by on-device ML Kit OCR.
class OcrTextLine {
  final String text;
  final ui.Rect boundingBox;
  const OcrTextLine({required this.text, required this.boundingBox});
}

/// Result of ML Kit OCR.
class OcrResult {
  final String fullText;
  final List<OcrTextLine> lines;

  /// Image dimensions as displayed (post-EXIF rotation).
  /// This matches how Flutter's Image.file renders the photo.
  final ui.Size imageSize;

  const OcrResult({
    required this.fullText,
    required this.lines,
    required this.imageSize,
  });
}

/// Runs on-device OCR via Google ML Kit.
class MlkitOcrService {
  final _recognizer = TextRecognizer();

  Future<OcrResult> recognizeText(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();

      // Read EXIF orientation to determine if width/height are swapped
      final exifOrientation = _readExifOrientation(bytes);
      final isRotated = exifOrientation >= 5 && exifOrientation <= 8;

      // Get raw pixel dimensions
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final rawW = frame.image.width.toDouble();
      final rawH = frame.image.height.toDouble();
      frame.image.dispose();
      codec.dispose();

      // Display size: Flutter auto-applies EXIF rotation, so swap if rotated
      final displaySize = isRotated ? ui.Size(rawH, rawW) : ui.Size(rawW, rawH);

      // ML Kit processes with InputImage.fromFilePath which reads EXIF
      // and returns bounding boxes in the display-oriented coordinate system.
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(inputImage);

      final lines = <OcrTextLine>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          lines.add(OcrTextLine(
            text: line.text,
            boundingBox: line.boundingBox,
          ));
        }
      }

      final fullText = recognized.blocks.map((b) => b.text).join('\n');
      return OcrResult(
          fullText: fullText, lines: lines, imageSize: displaySize);
    } catch (e) {
      throw OcrException('OCR failed for $imagePath: $e');
    }
  }

  /// Read EXIF orientation tag from JPEG bytes.
  /// Returns 1-8 (1 = normal, 6 = rotated 90° CW, 8 = rotated 90° CCW).
  /// Returns 1 (normal) if not a JPEG or tag not found.
  int _readExifOrientation(Uint8List bytes) {
    if (bytes.length < 12) return 1;
    // Check JPEG SOI marker
    if (bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;

    var offset = 2;
    while (offset < bytes.length - 4) {
      if (bytes[offset] != 0xFF) return 1;
      final marker = bytes[offset + 1];

      // APP1 marker (EXIF)
      if (marker == 0xE1) {
        final exifStart = offset + 4;

        // Check "Exif\0\0"
        if (exifStart + 6 > bytes.length) return 1;
        if (bytes[exifStart] != 0x45 ||
            bytes[exifStart + 1] != 0x78 ||
            bytes[exifStart + 2] != 0x69 ||
            bytes[exifStart + 3] != 0x66) {
          return 1;
        }

        final tiffStart = exifStart + 6;
        if (tiffStart + 8 > bytes.length) return 1;

        // Determine byte order
        final bigEndian = bytes[tiffStart] == 0x4D; // 'M' = big endian

        int read16(int pos) {
          if (pos + 2 > bytes.length) return 0;
          return bigEndian
              ? (bytes[pos] << 8) | bytes[pos + 1]
              : bytes[pos] | (bytes[pos + 1] << 8);
        }

        // Read IFD0 offset
        final ifdOffset = bigEndian
            ? (bytes[tiffStart + 4] << 24) |
                (bytes[tiffStart + 5] << 16) |
                (bytes[tiffStart + 6] << 8) |
                bytes[tiffStart + 7]
            : bytes[tiffStart + 4] |
                (bytes[tiffStart + 5] << 8) |
                (bytes[tiffStart + 6] << 16) |
                (bytes[tiffStart + 7] << 24);

        final ifdPos = tiffStart + ifdOffset;
        if (ifdPos + 2 > bytes.length) return 1;

        final numEntries = read16(ifdPos);
        for (var i = 0; i < numEntries; i++) {
          final entryPos = ifdPos + 2 + (i * 12);
          if (entryPos + 12 > bytes.length) return 1;

          final tag = read16(entryPos);
          if (tag == 0x0112) {
            // Orientation tag
            return read16(entryPos + 8);
          }
        }
        return 1;
      }

      // Skip to next segment
      final segLen =
          (bytes[offset + 2] << 8) | bytes[offset + 3];
      offset += 2 + segLen;
    }
    return 1;
  }

  void dispose() {
    _recognizer.close();
  }
}

/// Exception thrown when on-device OCR fails.
class OcrException implements Exception {
  final String message;
  OcrException(this.message);

  @override
  String toString() => message;
}
