import 'package:flutter/material.dart';

class ColorUtils {
  /// Get a darkened version of a color for better contrast
  static Color getDarkenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
    );
  }

  /// Get a lightened version of a color
  static Color getLightenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red + (255 - color.red) * factor).round(),
      (color.green + (255 - color.green) * factor).round(),
      (color.blue + (255 - color.blue) * factor).round(),
    );
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
