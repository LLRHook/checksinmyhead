import 'package:flutter/material.dart';
import 'dart:math';

/// Utility class for animations and custom painters
class AnimationUtils {
  // Any shared animation-related methods could go here
}

/// A custom painter that creates a pulsing effect
class PulsePainter extends CustomPainter {
  final Color color;

  PulsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Create multiple pulse waves with different opacities and sizes
    for (int i = 0; i < 3; i++) {
      final animationPhase =
          (DateTime.now().millisecondsSinceEpoch / 1500 + i * 0.33) % 1.0;

      // Adjust the pulse radius based on the animation phase
      final pulseRadius = maxRadius * animationPhase;

      // Make the pulse fade out as it expands
      final opacity = (1.0 - animationPhase) * 0.4;

      final paint =
          Paint()
            ..color = color.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

      canvas.drawCircle(center, pulseRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint to animate
  }
}
