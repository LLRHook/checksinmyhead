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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Preprocesses receipt images to improve ML Kit OCR accuracy.
///
/// Pipeline: grayscale → contrast boost (1.5×) → sharpen (3×3 convolution).
/// Runs in an isolate via [compute] to avoid blocking the UI thread.
class ImagePreprocessor {
  /// Preprocess the image at [inputPath] and write the result to a temp file.
  ///
  /// Returns the path to the preprocessed image, or null if processing fails.
  /// The caller is responsible for deleting the temp file when done.
  static Future<String?> preprocess(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final processed = await compute(_processIsolate, bytes);
      if (processed == null) return null;

      final tempDir = await Directory.systemTemp.createTemp('receipt_');
      final outputPath = '${tempDir.path}/preprocessed.png';
      await File(outputPath).writeAsBytes(processed);
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  /// Process raw image bytes through the preprocessing pipeline.
  /// Public for unit testing without file I/O.
  static Uint8List? processBytes(Uint8List bytes) {
    return _processIsolate(bytes);
  }

  static Uint8List? _processIsolate(Uint8List bytes) {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // 1. Grayscale
      image = img.grayscale(image);

      // 2. Contrast boost (1.5×)
      image = img.adjustColor(image, contrast: 1.5);

      // 3. Sharpen (3×3 convolution kernel)
      image = img.convolution(image, filter: [
        0, -1, 0, //
        -1, 5, -1, //
        0, -1, 0, //
      ], div: 1);

      return Uint8List.fromList(img.encodePng(image));
    } catch (_) {
      return null;
    }
  }
}
