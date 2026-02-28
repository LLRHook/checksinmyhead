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

import 'dart:math';
import 'package:flutter/material.dart';

/// Paints an annular hue ring using a SweepGradient.
///
/// The ring spans from [innerRadius] to [outerRadius] and shows the full
/// hue spectrum (red -> yellow -> green -> cyan -> blue -> magenta -> red).
/// A white circle indicator marks the currently selected [hue] angle.
class HueRingPainter extends CustomPainter {
  final double hue; // 0–360
  final double innerRadius;
  final double outerRadius;

  HueRingPainter({
    required this.hue,
    required this.innerRadius,
    required this.outerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw the hue ring
    final ringRect = Rect.fromCircle(center: center, radius: outerRadius);
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFFF0000), // 0°   Red
          Color(0xFFFFFF00), // 60°  Yellow
          Color(0xFF00FF00), // 120° Green
          Color(0xFF00FFFF), // 180° Cyan
          Color(0xFF0000FF), // 240° Blue
          Color(0xFFFF00FF), // 300° Magenta
          Color(0xFFFF0000), // 360° Red (wrap)
        ],
        transform: GradientRotation(-pi / 2), // Rotate so 0° (Red) is at top
      ).createShader(ringRect);

    // Clip to annular ring shape
    canvas.save();
    final outerPath = Path()..addOval(ringRect);
    final innerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.clipPath(
      Path.combine(PathOperation.difference, outerPath, innerPath),
    );
    canvas.drawOval(ringRect, ringPaint);
    canvas.restore();

    // Draw indicator circle on the ring at the selected hue
    final midRadius = (innerRadius + outerRadius) / 2;
    final angle = (hue - 90) * pi / 180; // -90 so 0° is at top
    final indicatorCenter = Offset(
      center.dx + midRadius * cos(angle),
      center.dy + midRadius * sin(angle),
    );
    final indicatorRadius = (outerRadius - innerRadius) / 2 - 1;

    // White outline
    canvas.drawCircle(
      indicatorCenter,
      indicatorRadius + 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Fill with the selected hue color
    canvas.drawCircle(
      indicatorCenter,
      indicatorRadius,
      Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );
  }

  @override
  bool shouldRepaint(covariant HueRingPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

/// Paints a saturation-brightness square filled with the given [hue].
///
/// Horizontal axis = saturation (left=0, right=1).
/// Vertical axis = brightness (top=1, bottom=0).
/// A circle selector marks the current [saturation] and [brightness].
class SaturationBrightnessPainter extends CustomPainter {
  final double hue; // 0–360
  final double saturation; // 0–1
  final double brightness; // 0–1

  SaturationBrightnessPainter({
    required this.hue,
    required this.saturation,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    canvas.save();
    canvas.clipRRect(rrect);

    // Base hue fill
    canvas.drawRect(
      rect,
      Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );

    // White → transparent horizontal gradient (saturation)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    // Transparent → black vertical gradient (brightness)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Colors.black],
        ).createShader(rect),
    );

    canvas.restore();

    // Draw selector circle
    final selectorX = saturation * size.width;
    final selectorY = (1 - brightness) * size.height;
    final selectorCenter = Offset(selectorX, selectorY);
    final selectedColor =
        HSVColor.fromAHSV(1, hue, saturation, brightness).toColor();

    // White outline for visibility on any background
    canvas.drawCircle(
      selectorCenter,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Fill with selected color
    canvas.drawCircle(
      selectorCenter,
      8,
      Paint()..color = selectedColor,
    );
  }

  @override
  bool shouldRepaint(covariant SaturationBrightnessPainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.brightness != brightness;
}
