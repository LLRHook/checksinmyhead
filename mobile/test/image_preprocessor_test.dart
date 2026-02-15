import 'dart:typed_data';

import 'package:checks_frontend/services/image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ImagePreprocessor.processBytes', () {
    test('processes a synthetic image and preserves dimensions', () {
      // Create a 100x100 test image with a drawn line
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.drawLine(image,
          x1: 10, y1: 50, x2: 90, y2: 50, color: img.ColorRgb8(0, 0, 0));

      final inputBytes = Uint8List.fromList(img.encodePng(image));
      final result = ImagePreprocessor.processBytes(inputBytes);

      expect(result, isNotNull);

      final decoded = img.decodePng(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 100);
      expect(decoded.height, 100);
    });

    test('returns null for invalid image data', () {
      final garbage = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final result = ImagePreprocessor.processBytes(garbage);

      expect(result, isNull);
    });

    test('output is grayscale', () {
      // Create image with a bright red pixel
      final image = img.Image(width: 10, height: 10);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));

      final inputBytes = Uint8List.fromList(img.encodePng(image));
      final result = ImagePreprocessor.processBytes(inputBytes);

      expect(result, isNotNull);
      final decoded = img.decodePng(result!)!;

      // In a grayscale image, R == G == B for every pixel
      final pixel = decoded.getPixel(5, 5);
      expect(pixel.r, pixel.g);
      expect(pixel.g, pixel.b);
    });
  });
}
