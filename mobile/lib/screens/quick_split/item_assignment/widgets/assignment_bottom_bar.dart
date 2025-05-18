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

/// A customized bottom bar widget for the assignment screen that displays
/// the total bill amount and provides a continue button for navigation.
///
/// This widget creates a persistent bottom bar with:
/// - Total bill amount display on the left side
/// - Continue button with arrow icon on the right side
/// - Theme-aware styling for both light and dark modes
/// - Subtle shadow effect for visual depth
///
/// The bottom bar is designed to provide clear next steps for users while
/// maintaining visibility of the important bill total information.
///
/// Example usage:
/// ```dart
/// AssignmentBottomBar(
///   totalBill: 45.75,
///   onContinueTap: () => Navigator.push(context, MaterialPage(...)),
/// )
/// ```
class AssignmentBottomBar extends StatelessWidget {
  /// The total bill amount to display, typically in dollars
  final double totalBill;

  /// Callback function executed when the continue button is tapped
  final VoidCallback onContinueTap;

  /// Creates an AssignmentBottomBar with the required parameters
  ///
  /// Both [totalBill] and [onContinueTap] must be provided.
  const AssignmentBottomBar({
    super.key,
    required this.totalBill,
    required this.onContinueTap,
  });

  @override
  Widget build(BuildContext context) {
    // Access theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors that adapt to light/dark mode
    // Background color uses different surface colors based on brightness
    final backgroundColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Theme.of(context).scaffoldBackgroundColor;

    // Shadow intensity varies by theme brightness for proper visual hierarchy
    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .2)
            : Colors.black.withValues(alpha: .05);

    // Label color is more subdued than the value color
    final labelColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .7)
            : Colors.grey;

    // Value color uses the main contrast color for visibility
    final valueColor = colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -3), // Shadow appears above the container
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bill total information section
            // Fixed position on the left side
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Bill',
                  style: TextStyle(fontSize: 12, color: labelColor),
                ),
                Text(
                  '\$${totalBill.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor, // Theme-aware price color
                  ),
                ),
              ],
            ),

            // Continue button section
            // Fixed position on the right side
            ElevatedButton(
              onPressed: onContinueTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                // Button text color adapts to provide better contrast in different themes
                foregroundColor:
                    brightness == Brightness.dark
                        ? Colors.black.withValues(
                          alpha: .9,
                        ) // Better contrast in dark mode
                        : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 2,
                shadowColor: colorScheme.primary.withValues(alpha: .4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
