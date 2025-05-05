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

  /// Get a list of modern, visually distinct colors for participants
  static List<Color> getParticipantColors() {
    return [
      const Color(0xFF5E35B1), // Deep Purple
      const Color(0xFF00ACC1), // Cyan
      const Color(0xFFD81B60), // Pink
      const Color(0xFF43A047), // Green
      const Color(0xFF6200EA), // Deep Purple A700
      const Color(0xFFFFB300), // Amber
      const Color(0xFF3949AB), // Indigo
      const Color(0xFF00897B), // Teal
      const Color(0xFFE64A19), // Deep Orange
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF8E24AA), // Purple
      const Color(0xFFC0CA33), // Lime
      const Color(0xFFF4511E), // Deep Orange
      const Color(0xFF039BE5), // Light Blue
      const Color(0xFF7CB342), // Light Green
      const Color(0xFFD50000), // Red A700
    ];
  }

  static bool isPurplish(Color baseColor) {
    return baseColor.red > baseColor.green && baseColor.blue > baseColor.green;
  }
}

/// Extension for easier Color manipulation
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromARGB(
      alpha != null ? (alpha * 255).round() : this.alpha,
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
    );
  }
}
