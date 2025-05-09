// Checkmate: Privacy-first receipt spliting
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

import 'package:flutter/animation.dart';
import 'dart:math' show sin, pi;

/// Custom animation curves and utilities
class AnimationUtils {
  /// Creates a gentle shake animation for error feedback
  static Animation<Offset> createShakeAnimation({
    required AnimationController controller,
    double intensity = 0.02,
    int count = 3,
  }) {
    return Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: ShakeCurve(count: count, intensity: intensity),
      ),
    );
  }
}

/// Custom curve to create a shake animation effect
class ShakeCurve extends Curve {
  /// Number of oscillations in the shake
  final int count;

  /// How strong the shake should be (amplitude)
  final double intensity;

  const ShakeCurve({this.count = 3, this.intensity = 0.05});

  @override
  double transform(double t) {
    // Sin wave that decreases in amplitude over time
    return sin(count * 2 * pi * t) * intensity * (1 - t);
  }
}

/// Custom curve for a bouncy entrance
class BouncyEntranceCurve extends Curve {
  @override
  double transform(double t) {
    // Overshoot slightly then settle back
    return -15.0 * (t - 1.0) * (t - 1.0) * (t - 1.0) * (t - 1.0) + 1.0;
  }
}

/// Custom curve for a gentle pulse
class PulseCurve extends Curve {
  @override
  double transform(double t) {
    // Subtle pulse effect
    if (t < 0.5) {
      return 1.0 + (sin(pi * t) * 0.1);
    } else {
      return 1.0 + (sin(pi * t) * 0.05);
    }
  }
}
