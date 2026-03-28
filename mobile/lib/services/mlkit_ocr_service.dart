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
  final ui.Size imageSize;
  const OcrResult(
      {required this.fullText, required this.lines, required this.imageSize});
}

/// Runs on-device OCR via Google ML Kit.
class MlkitOcrService {
  final _recognizer = TextRecognizer();

  Future<OcrResult> recognizeText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final imageSize = await _resolveImageSize(imagePath);
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
      return OcrResult(fullText: fullText, lines: lines, imageSize: imageSize);
    } catch (e) {
      throw OcrException('OCR failed for $imagePath: $e');
    }
  }

  Future<ui.Size> _resolveImageSize(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = ui.Size(
        frame.image.width.toDouble(), frame.image.height.toDouble());
    frame.image.dispose();
    codec.dispose();
    return size;
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
