// Billington: Privacy-first receipt spliting
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

/// A customized AppBar widget specifically designed for the item assignment screens.
///
/// This AppBar provides a consistent navigation experience with:
/// - A back button for returning to the previous screen
/// - An optional help button that can be toggled on/off
/// - Theme-aware styling that adapts to both light and dark modes
///
/// The AppBar maintains a clean, minimal design with zero elevation and proper
/// accessibility features like tooltips on interactive elements.
///
/// Example usage:
/// ```dart
/// AssignmentAppBar(
///   onBackPressed: () => Navigator.pop(context),
///   onHelpPressed: _showTutorial,
///   showHelpButton: true,
/// )
/// ```
class AssignmentAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Callback function executed when the back button is pressed
  final VoidCallback onBackPressed;

  /// Optional callback function executed when the help button is pressed
  final VoidCallback? onHelpPressed;

  /// Controls the visibility of the help button in the AppBar
  /// When false, the help button will not be displayed regardless of onHelpPressed
  final bool showHelpButton;

  /// Creates an AssignmentAppBar with required and optional parameters
  ///
  /// The [onBackPressed] parameter is required to handle navigation.
  /// The [onHelpPressed] parameter is optional but needed if [showHelpButton] is true.
  /// The [showHelpButton] defaults to false if not specified.
  const AssignmentAppBar({
    super.key,
    required this.onBackPressed,
    this.onHelpPressed,
    this.showHelpButton = false,
  });

  @override
  Widget build(BuildContext context) {
    // Retrieve the current theme's color scheme for theme-aware styling
    final colorScheme = Theme.of(context).colorScheme;

    // Define theme-aware colors for consistent styling
    final backgroundColor = colorScheme.surface;
    final iconColor = colorScheme.onSurface;

    return AppBar(
      title: Text(
        'Assign Items',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface, // Theme-aware text color
        ),
      ),
      centerTitle: true,
      elevation: 0, // Flat design with no shadow
      backgroundColor: backgroundColor,
      foregroundColor: iconColor, // Theme-aware icons and text
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: onBackPressed,
        color: iconColor, // Ensure icon respects theme
      ),
      actions: [
        // Conditionally display the help button only when both:
        // 1. showHelpButton is true, and
        // 2. onHelpPressed callback is provided
        if (showHelpButton && onHelpPressed != null)
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: onHelpPressed,
            tooltip: 'Show Tutorial', // Accessibility enhancement
            color:
                colorScheme
                    .primary, // Use primary color for help icon to draw attention
          ),
      ],
    );
  }

  /// Defines the preferred size for this widget
  ///
  /// Uses the standard toolbar height (kToolbarHeight) defined in the Material library
  /// This implementation is required by the PreferredSizeWidget interface
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
