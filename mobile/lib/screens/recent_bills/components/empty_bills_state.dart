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
import 'package:flutter/services.dart';

/// EmptyBillsState
///
/// A widget that provides a visually appealing empty state for the bills screen
/// when no bills have been created yet. This component displays an informative
/// message and a call-to-action button that guides users to create their first bill.
///
/// Features:
/// - Visually engaging empty state with icon, title, and description
/// - Theme-aware styling that adapts to light/dark mode for optimal readability
/// - Prominent call-to-action button with haptic feedback
/// - Responsive layout that works across different screen sizes
///
/// This component is designed to provide a good first-time user experience,
/// clearly communicating the next steps to users who haven't created any bills yet.
class EmptyBillsState extends StatelessWidget {
  const EmptyBillsState({super.key});

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors for optimal readability in both modes
    // Icon uses primary color in both light and dark modes
    final iconColor = colorScheme.primary;

    // Title uses full surface color for maximum contrast
    final titleColor = colorScheme.onSurface;

    // Subtitle uses slightly transparent color - more opaque in dark mode for better readability
    final subtitleColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(
              alpha: 0.8,
            ) // More visible in dark mode
            : colorScheme.onSurface.withValues(alpha: 0.7);

    // Button text color - dark in dark mode for better contrast on bright buttons
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(
              alpha: 0.9,
            ) // Dark text on bright button in dark mode
            : Colors.white; // White text on colored button in light mode

    // Button shadow - more pronounced in dark mode for better visual hierarchy
    final buttonShadowColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(
              alpha: 0.6,
            ) // More visible shadow in dark mode
            : colorScheme.primary.withValues(alpha: 0.4);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container with fixed size for visual consistency
            SizedBox(
              width: 80,
              height: 80,
              child: Icon(Icons.receipt_long, size: 40, color: iconColor),
            ),
            const SizedBox(height: 24),

            // Main title - bold and prominent
            Text(
              'No Bills Yet!',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 16),

            // Descriptive subtitle with center alignment
            Text(
              'Make your first bill to get started.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: subtitleColor),
            ),
            const SizedBox(height: 32),

            // Call-to-action button with premium styling and haptic feedback
            ElevatedButton.icon(
              onPressed: () {
                // Provide tactile feedback when button is pressed
                HapticFeedback.mediumImpact();

                // Navigate back to create a new bill
                // This assumes this screen was pushed on top of the bill creation screen
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: buttonTextColor,
                // Generous padding for better touch target
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                // Rounded corners for modern look
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // Subtle elevation for depth
                elevation: 2,
                shadowColor: buttonShadowColor,
                // Typography styling for emphasis
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5, // Slight letter spacing for readability
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
