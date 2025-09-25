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

import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// ContinueButton - Context-aware action button for bill entry navigation
///
/// A prominent button that changes appearance and text based on the current
/// state of bill entry. Shows different states for:
/// - Items matching subtotal (success state with checkmark)
/// - Items added but not matching subtotal (standard continue)
/// - No items added (prompting user to add items)
///
/// Features:
/// - Visual feedback through color changes based on validation state
/// - Theme-aware styling for both light and dark modes
/// - Subtle elevation shadow for depth
/// - Adaptive text and icons based on current bill state
class ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ContinueButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Check if items total matches subtotal (with small tolerance for rounding errors)
    final isItemsMatchingSubtotal =
        billData.subtotal > 0 &&
        (billData.subtotal - billData.itemsTotal).abs() <= 0.01;

    // Use a distinct green color for success state
    final successColor =
        brightness == Brightness.dark
            ? const Color(0xFF66BB6A) // Softer green for dark mode
            : const Color(0xFF4CAF50); // Standard green for light mode

    // Use success color when items match, otherwise use theme primary color
    final buttonColor =
        isItemsMatchingSubtotal ? successColor : colorScheme.primary;

    // Use dark text on bright backgrounds for better contrast in dark mode
    final textColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.9)
            : Colors.white;

    // Check if any items have been added
    final hasItems = billData.items.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(
              alpha: brightness == Brightness.dark ? 0.2 : 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success state - items match subtotal
            if (isItemsMatchingSubtotal) ...[
              Icon(Icons.check_circle, size: 20, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: textColor,
                ),
              ),
            ]
            // Items added but don't match subtotal
            else if (hasItems) ...[
              Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: textColor.withValues(alpha: .9),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: textColor.withValues(alpha: .9),
              ),
            ]
            // No items added yet
            else ...[
              Text(
                'Add Items & Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
