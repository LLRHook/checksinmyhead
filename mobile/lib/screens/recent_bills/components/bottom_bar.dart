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

import 'package:checks_frontend/screens/recent_bills/billDetails/utils/recent_bills_share_utils.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:flutter/material.dart';

/// RecentBillBottomBar
///
/// A specialized bottom bar widget that provides sharing functionality
/// for bills in the recent bills screen.
///
/// This component displays a "Share" button that enables users to share
/// bill details with others. It adapts its appearance based on the current
/// theme and provides visual feedback through styling.
///
/// Features:
/// - Theme-aware styling that adapts to light/dark mode
/// - Elevated appearance with subtle shadow effect
/// - Safe area awareness to handle device notches and home indicators
/// - Consistent padding and rounded corners for better aesthetics
///
/// This component is designed to be used as the bottomNavigationBar
/// in bill detail screens.
class RecentBillBottomBar extends StatelessWidget {
  /// The bill model containing the data to be shared
  final RecentBillModel bill;

  const RecentBillBottomBar({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors that adapt to light/dark mode
    // Background color - uses surface color in dark mode, white in light mode
    final backgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    // Shadow color - more pronounced in dark mode for better visibility
    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .2)
            : Colors.black.withValues(alpha: .03);

    // Button outline color - slightly transparent in dark mode for softer appearance
    final outlineColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .8)
            : colorScheme.primary;

    // Bottom bar container with elevation shadow and safe area protection
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            offset: const Offset(0, -2), // Shadow appears above the bar
          ),
        ],
      ),
      // SafeArea ensures the content doesn't overlap with system UI elements
      child: SafeArea(
        child: Row(
          children: [
            // Share button spans the full width of the container
            Expanded(
              child: OutlinedButton.icon(
                // When pressed, use the utility class to handle the share functionality
                onPressed: () => RecentBillShareUtils.shareBill(context, bill),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: outlineColor,
                  side: BorderSide(color: outlineColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  // Rounded corners for better visual appeal
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
