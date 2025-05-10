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

import 'package:flutter/material.dart';
import '/models/person.dart';

/// A utility class for color operations used throughout the app
///
/// This class provides methods for color manipulation, color assessment,
/// and generating appropriate colors for UI elements. It includes functionality for:
/// - Determining dominant colors from a collection of users/participants
/// - Lightening and darkening colors by specified amounts
/// - Assessing color properties (brightness, contrast requirements)
/// - Generating visually distinct color palettes for participant identification
class ColorUtils {
  /// Default color used when no specific color is assigned or available
  /// Slate gray provides a neutral option that works well with most UI designs
  static const Color slateGray = Color(0xFF64748B);

  /// Determines the most appropriate color to represent a group of people
  ///
  /// This method analyzes a list of assigned people and returns:
  /// - The default slate gray if no people are assigned
  /// - The color of the single person if only one person is assigned
  /// - The first person's color for multiple people (simple implementation)
  ///
  /// Parameters:
  /// - [assignedPeople]: List of Person objects assigned to an item/task
  ///
  /// Note: For multiple people, a more sophisticated color blending algorithm
  /// could be implemented here in future versions
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

  /// Lightens a color by a specified factor
  ///
  /// This method increases the brightness of a color by moving each RGB channel
  /// value toward white (255) by the specified factor.
  ///
  /// Parameters:
  /// - [color]: The base color to lighten
  /// - [factor]: A value between 0.0 and 1.0 where:
  ///   - 0.0 = No change to the original color
  ///   - 1.0 = Fully white
  ///
  /// Returns a new Color instance with lightened RGB values
  static Color getLightenedColor(Color color, double factor) {
    return Color.fromARGB(
      (color.a * 255.0).round(),
      ((color.r * 255.0) + (255 - (color.r * 255.0)) * factor).round(),
      ((color.g * 255.0) + (255 - (color.g * 255.0)) * factor).round(),
      ((color.b * 255.0) + (255 - (color.b * 255.0)) * factor).round(),
    );
  }

  /// Darkens a color by a specified factor
  ///
  /// This method decreases the brightness of a color by moving each RGB channel
  /// value toward black (0) by the specified factor.
  ///
  /// Parameters:
  /// - [color]: The base color to darken
  /// - [factor]: A value between 0.0 and 1.0 where:
  ///   - 0.0 = No change to the original color
  ///   - 1.0 = Fully black
  ///
  /// Returns a new Color instance with darkened RGB values
  static Color getDarkenedColor(Color color, double factor) {
    return Color.fromARGB(
      (color.a * 255.0).round() & 0xff,
      (((color.r * 255.0).round() & 0xff) * (1 - factor)).round(),
      (((color.g * 255.0).round() & 0xff) * (1 - factor)).round(),
      (((color.b * 255.0).round() & 0xff) * (1 - factor)).round(),
    );
  }

  /// Determines if a color is too light for dark text
  ///
  /// Uses a weighted formula based on human perception of color brightness:
  /// - Red contributes 29.9% to perceived brightness
  /// - Green contributes 58.7% to perceived brightness
  /// - Blue contributes 11.4% to perceived brightness
  ///
  /// Parameters:
  /// - [color]: The color to evaluate
  ///
  /// Returns true if the perceived brightness exceeds 70% (0.7)
  static bool isColorTooLight(Color color) {
    return (0.299 * ((color.r * 255.0).round() & 0xff) +
                0.587 * ((color.g * 255.0).round() & 0xff) +
                0.114 * ((color.b * 255.0).round() & 0xff)) /
            255 >
        0.7;
  }

  /// Provides a contrasting text color for optimal readability
  ///
  /// Given a background color, this method returns either black or white
  /// for the text color, based on which provides better contrast.
  ///
  /// Parameters:
  /// - [backgroundColor]: The background color to contrast against
  ///
  /// Returns Colors.black for light backgrounds and Colors.white for dark backgrounds
  static Color getContrastiveTextColor(Color backgroundColor) {
    return isColorTooLight(backgroundColor) ? Colors.black : Colors.white;
  }

  /// Returns a predefined palette of visually distinct colors for participants
  ///
  /// This method provides a collection of colors that:
  /// - Are visually distinguishable from each other
  /// - Have modern, appealing hues for UI design
  /// - Work well for user identification in the app
  ///
  /// The palette includes 16 colors spanning the color spectrum
  /// with emphasis on colors that work well with both light and dark themes
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

  /// Determines if a color is in the purple family
  ///
  /// This method checks if a color has more red and blue components than green,
  /// which is a simple heuristic for identifying purplish colors.
  ///
  /// Parameters:
  /// - [baseColor]: The color to evaluate
  ///
  /// Returns true if the color is likely in the purple family
  static bool isPurplish(Color baseColor) {
    return ((baseColor.r * 255.0).round() & 0xff) >
            ((baseColor.g * 255.0).round() & 0xff) &&
        ((baseColor.b * 255.0).round() & 0xff) >
            ((baseColor.g * 255.0).round() & 0xff);
  }

  /// Determines an appropriate color for a participant's avatar
  ///
  /// This method selects a color from a predefined palette based on the participant's
  /// index, and adjusts the brightness for dark mode to ensure good visibility.
  ///
  /// Parameters:
  /// - index: The participant's index in the list
  /// - colorScheme: The current theme's color scheme
  /// - brightness: The current theme's brightness (light/dark)
  ///
  /// Returns a color appropriate for the participant's avatar
  static Color getPersonColor(
    int index,
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    // Color palette for avatars - uses theme colors and standard material colors
    final colors = [
      colorScheme.primary,
      colorScheme.tertiary,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.deepPurple,
      Colors.pink,
      Colors.brown,
    ];

    // Select color based on index (wrap around if more participants than colors)
    final baseColor = colors[index % colors.length];

    // For dark mode, check if the color needs to be lightened for visibility
    if (brightness == Brightness.dark) {
      // Calculate approximate luminance using RGB components
      // This simplified formula gives a value between 0-1 indicating brightness
      final luminance =
          (0.299 * ((baseColor.r * 255.0).round() & 0xff) +
              0.587 * ((baseColor.g * 255.0).round() & 0xff) +
              0.114 * ((baseColor.b * 255.0).round() & 0xff)) /
          255;

      // If color is too dark (luminance < 0.5), lighten it
      if (luminance < 0.5) {
        return _lightenColor(baseColor, 0.2); // Lighten by 20%
      }
    }

    return baseColor;
  }

  /// Helper method to lighten a color by a specified amount
  ///
  /// This utility function creates a lighter version of the provided color
  /// by moving each RGB component towards white by the specified percentage.
  ///
  /// Parameters:
  /// - color: The original color to lighten
  /// - amount: The amount to lighten (0.0 to 1.0, where 1.0 is white)
  ///
  /// Returns a new color that is lighter than the original
  static Color _lightenColor(Color color, double amount) {
    return Color.fromARGB(
      (color.a * 255.0).round() & 0xff,
      (((color.r * 255.0).round() & 0xff) +
              (255 - ((color.r * 255.0).round() & 0xff)) * amount)
          .round(), // Move red towards 255
      (((color.g * 255.0).round() & 0xff) +
              (255 - ((color.g * 255.0).round() & 0xff)) * amount)
          .round(), // Move green towards 255
      (((color.b * 255.0).round() & 0xff) +
              (255 - ((color.b * 255.0).round() & 0xff)) * amount)
          .round(), // Move blue towards 255
    );
  }

  /// Adjusts colors for better visibility in dark mode
  ///
  /// This helper method brightens colors that would be too dark
  /// to see properly in dark mode.
  ///
  /// Parameters:
  /// - color: The original color to adjust
  ///
  /// Returns a color that is visible in dark mode
  static Color adjustColorForDarkMode(Color color) {
    // If the color is too dark (luminance < 0.4), brighten it
    if (_luminance(color) < 0.4) {
      // Convert to HSL color space to adjust lightness while preserving hue
      final HSLColor hslColor = HSLColor.fromColor(color);
      // Increase lightness by 20%, clamped to valid range
      return hslColor
          .withLightness((hslColor.lightness + 0.2).clamp(0.0, 1.0))
          .toColor();
    }
    return color; // No adjustment needed
  }

  /// Calculates the relative luminance of a color
  ///
  /// This utility method calculates the perceived brightness of a color
  /// using the standard luminance formula.
  ///
  /// Parameters:
  /// - color: The color to calculate luminance for
  ///
  /// Returns a value between 0.0 (black) and 1.0 (white)
  static double _luminance(Color color) {
    // Standard formula for relative luminance
    // Red contributes 30%, green 59%, blue 11% to perceived brightness
    return (0.299 * ((color.r * 255.0).round() & 0xff) +
            0.587 * ((color.g * 255.0).round() & 0xff) +
            0.114 * ((color.b * 255.0).round() & 0xff)) /
        255;
  }
}
