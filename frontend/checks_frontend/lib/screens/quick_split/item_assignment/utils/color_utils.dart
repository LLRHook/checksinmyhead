import 'package:flutter/material.dart';
import '/models/person.dart';

/// A utility class for color operations used throughout the app
class ColorUtils {
  // Color constants
  static const Color slateGray = Color(0xFF64748B);

  /// Get the dominant color from a list of assigned people
  static Color getDominantColor(List<Person> assignedPeople) {
    if (assignedPeople.isEmpty) {
      return slateGray;
    } else if (assignedPeople.length == 1) {
      return assignedPeople.first.color;
    } else {
      // For multiple people, use the first person's color
      // You could also implement a more sophisticated blending here
      return assignedPeople.first.color;
    }
  }

  /// Lighten a color by a factor (0-1)
  static Color getLightenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red + (255 - color.red) * factor).round(),
      (color.green + (255 - color.green) * factor).round(),
      (color.blue + (255 - color.blue) * factor).round(),
    );
  }

  /// Darken a color by a factor (0-1)
  static Color getDarkenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
    );
  }

  /// Check if a color is considered "light"
  static bool isColorTooLight(Color color) {
    return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) /
            255 >
        0.7;
  }

  /// Get a contrasting text color (black/white) based on background
  static Color getContrastiveTextColor(Color backgroundColor) {
    return isColorTooLight(backgroundColor) ? Colors.black : Colors.white;
  }
}
