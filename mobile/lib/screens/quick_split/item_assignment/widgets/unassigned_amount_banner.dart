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
import 'package:flutter/services.dart';

/// UnassignedAmountBanner
///
/// A notification banner that displays the amount of money that hasn't been
/// assigned to participants and provides a call-to-action to split it evenly.
///
/// This widget adapts to the current theme (light/dark mode) with appropriate
/// color adjustments for optimal visibility and consistent styling.
///
/// The banner includes:
/// - Warning icon to draw attention
/// - Amount not assigned with currency formatting
/// - Explanatory text encouraging user action
/// - Visual indicator (hand icon) suggesting the banner is tappable
///
/// When tapped, the banner triggers haptic feedback and executes the provided
/// onSplitEvenly callback.
///
/// Inputs:
/// - unassignedAmount: The dollar amount that hasn't been assigned to participants
/// - onSplitEvenly: Callback function to execute when banner is tapped
///
/// Side effects:
/// - Triggers medium haptic feedback on tap for better user experience
class UnassignedAmountBanner extends StatelessWidget {
  final double unassignedAmount;
  final VoidCallback onSplitEvenly;

  const UnassignedAmountBanner({
    super.key,
    required this.unassignedAmount,
    required this.onSplitEvenly,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors for consistent appearance in both light and dark modes
    final backgroundColor =
        brightness == Brightness.dark
            ? Color(0xFF442700).withValues(
              alpha: .4,
            ) // Dark orange background with opacity for dark mode
            : Colors.orange.shade50; // Light orange background for light mode

    final borderColor =
        brightness == Brightness.dark
            ? Colors.orange.shade700.withValues(alpha: .4)
            : Colors.orange.shade200;

    final iconColor =
        brightness == Brightness.dark
            ? Colors.orange.shade300
            : Colors.orange.shade700;

    final titleColor =
        brightness == Brightness.dark
            ? Colors.orange.shade200
            : Colors.orange.shade900;

    final subtitleColor =
        brightness == Brightness.dark
            ? Colors.orange.shade300.withValues(alpha: .7)
            : Colors.orange.shade800;

    // Using GestureDetector instead of InkWell for better control over touch behavior
    // and to enable haptic feedback functionality
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact(); // Provide tactile feedback when tapped
        onSplitEvenly();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Warning icon to draw attention to the unassigned amount
              Icon(Icons.warning_amber_rounded, color: iconColor, size: 24),
              const SizedBox(width: 12),

              // Text content with amount and action suggestion
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Format currency with 2 decimal places for consistency
                    Text(
                      "\$${unassignedAmount.toStringAsFixed(2)} not assigned",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Tap to split evenly among participants',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),

              // Touch icon indicates the banner is interactive
              Icon(Icons.touch_app, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
