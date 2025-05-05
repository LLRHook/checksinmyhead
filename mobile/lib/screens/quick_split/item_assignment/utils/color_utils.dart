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
      color.alpha,
      (color.red + (255 - color.red) * factor).round(),
      (color.green + (255 - color.green) * factor).round(),
      (color.blue + (255 - color.blue) * factor).round(),
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
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
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
    return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) /
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
    return baseColor.red > baseColor.green && baseColor.blue > baseColor.green;
  }
}
