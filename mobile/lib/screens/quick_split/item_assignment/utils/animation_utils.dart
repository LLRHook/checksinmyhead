import 'package:flutter/material.dart';

/// A custom painter that creates a pulsing animation effect by drawing multiple concentric circles
/// that expand and fade out over time.
///
/// This painter is designed to be used in a continuously repainting widget (like CustomPaint)
/// that calls shouldRepaint frequently to create the animation effect.
///
/// Parameters:
///   - color: The base color of the pulsing circles. The opacity of this color
///     will be dynamically adjusted based on the animation phase.
///
/// Usage example:
///   ```
///   CustomPaint(
///     painter: PulsePainter(color: Colors.blue),
///     size: Size(200, 200),
///   )
///   ```
class PulsePainter extends CustomPainter {
  final Color color;

  PulsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Create multiple pulse waves with different phases to create a continuous pulsing effect
    // The number of circles (3) determines how dense the animation appears
    for (int i = 0; i < 3; i++) {
      // Calculate a unique animation phase for each circle based on current time
      // Dividing by 1500 controls the speed of the animation (milliseconds per cycle)
      // Adding i * 0.33 offsets each circle by approximately one-third of the animation cycle
      final animationPhase =
          (DateTime.now().millisecondsSinceEpoch / 1500 + i * 0.33) % 1.0;

      // Scale the radius based on animation phase - circles grow outward from 0 to maxRadius
      final pulseRadius = maxRadius * animationPhase;

      // Inverse relationship between size and opacity creates the fading effect
      // Multiplying by 0.4 controls the maximum opacity of the circles
      final opacity = (1.0 - animationPhase) * 0.4;

      final paint =
          Paint()
            ..color = color.withValues(alpha: opacity)
            ..style =
                PaintingStyle
                    .stroke // Draw outline only, not filled circles
            ..strokeWidth = 2.0; // Thickness of the circle outline

      canvas.drawCircle(center, pulseRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
