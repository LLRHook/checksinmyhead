// Spliq: Privacy-first receipt spliting
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

/// AppInputDecoration - Utility class for consistent text input styling
///
/// Provides a factory method to create standardized InputDecoration objects
/// with theme-aware styling that adapts to light and dark modes.
///
/// Purpose:
///   Creates consistent, theme-aware text field decorations across the app
///
/// Inputs:
///   - context: BuildContext for accessing theme data
///   - labelText: The label text displayed above the input
///   - prefixText: Optional text to display at the start of the input
///   - hintText: Optional placeholder text shown when the field is empty
///   - prefixIcon: Optional icon to display at the start of the input
///
/// Output:
///   Returns an InputDecoration configured with appropriate styling for the current theme
class AppInputDecoration {
  /// Creates a standardized InputDecoration with theme-aware styling
  ///
  /// Automatically adapts colors and appearance based on the current theme (light/dark)
  static InputDecoration buildInputDecoration({
    required BuildContext context,
    required String labelText,
    String? prefixText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Semi-transparent label color for better contrast while remaining subtle
    final labelColor = colorScheme.onSurface.withValues(alpha: .7);

    // Background fill color - darker in dark mode, light gray in light mode
    final fillColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade50;

    // Border color - uses theme outline in dark mode, light gray in light mode
    final borderColor =
        brightness == Brightness.dark
            ? colorScheme.outline
            : Colors.grey.shade200;

    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w500),
      prefixText: prefixText,
      prefixIcon:
          prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: labelColor)
              : null,
      hintText: hintText,
      hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: .5)),
      filled: true,
      fillColor: fillColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
