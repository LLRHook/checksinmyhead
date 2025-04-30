import 'package:flutter/material.dart';

// Helper to get a lightened version of a color (more white)
Color getLightenedColor(Color color, double factor) {
  return Color.fromARGB(
    color.alpha,
    (color.red + (255 - color.red) * factor).round(),
    (color.green + (255 - color.green) * factor).round(),
    (color.blue + (255 - color.blue) * factor).round(),
  );
}

// Helper to get a darkened version of a color
Color getDarkenedColor(Color color, double factor) {
  return Color.fromARGB(
    color.alpha,
    (color.red * (1 - factor)).round(),
    (color.green * (1 - factor)).round(),
    (color.blue * (1 - factor)).round(),
  );
}

// Helper to determine if a color is too light for white text
bool isColorTooLight(Color color) {
  return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255 >
      0.7;
}

// Helper to get a contrastive text color (black or white) based on background
Color getContrastiveTextColor(Color backgroundColor) {
  return isColorTooLight(backgroundColor) ? Colors.black : Colors.white;
}
