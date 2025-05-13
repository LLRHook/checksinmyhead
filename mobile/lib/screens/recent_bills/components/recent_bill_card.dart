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

import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:checks_frontend/screens/recent_bills/billDetails/bill_details_screen.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/recent_bills/recent_bills_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

/// RecentBillCard
///
/// A card widget that displays a summary of a recent bill in the bill history list.
/// This component serves as an entry point to view detailed bill information and
/// provides quick actions for managing the bill.
///
/// Features:
/// - Displays key bill information (date, participants, total amount)
/// - Theme-aware styling that adapts to light/dark mode
/// - Interactive elements with visual feedback (ripple effects, haptic feedback)
/// - Quick actions for viewing details or deleting the bill
/// - Confirmation dialog for delete operations
///
/// This component is designed to be used within a list of recent bills, providing
/// a consistent and visually appealing way to browse bill history.
class RecentBillCard extends StatelessWidget {
  /// The bill model containing data to display
  final RecentBillModel bill;

  /// Callback function to notify parent when this bill is deleted
  final VoidCallback onDeleted;

  /// Callback function to trigger a refresh of the bills list
  final VoidCallback onRefreshNeeded;

  const RecentBillCard({
    super.key,
    required this.bill,
    required this.onDeleted,
    required this.onRefreshNeeded,
  });

  /// Navigates to the bill details screen with haptic feedback
  ///
  /// This method provides tactile feedback and navigates to a detailed
  /// view of the bill when the card is tapped.
  Future<void> _navigateToBillDetails(BuildContext context) async {
    // Provide subtle haptic feedback for better user experience
    HapticFeedback.selectionClick();

    // Navigate to the bill details screen and listen for name changes
    final wasUpdated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => BillDetailsScreen(bill: bill)),
    );

    // If bill name was updated, trigger a refresh instead of deletion
    if (wasUpdated == true) {
      // Use the dedicated refresh callback
      onRefreshNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors for adaptive styling
    // Card background - surface color in dark mode, white in light mode
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    // Card shadow - more pronounced in dark mode for better visibility
    final cardShadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .2)
            : Colors.black.withValues(alpha: .04);

    // Divider color - subtle in both modes
    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .2)
            : Colors.grey.shade100;

    // Date text color - full contrast for good readability
    final dateColor = colorScheme.onSurface;

    // Participants text color - slightly reduced opacity for visual hierarchy
    final participantsTextColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .7)
            : colorScheme.onSurface.withValues(alpha: .6);

    // Adjust bill color for better visibility in dark mode if needed
    final adjustedBillColor =
        brightness == Brightness.dark
            ? ColorUtils.adjustColorForDarkMode(bill.color)
            : bill.color;

    // Dialog background color
    final dialogBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    // Build the card UI
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2), // Shadow below the card
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent, // Allows ink effects to show
          child: InkWell(
            onTap: () => _navigateToBillDetails(context), // Navigate on tap
            splashColor: adjustedBillColor.withValues(
              alpha: .1,
            ), // Custom splash using bill color
            highlightColor: adjustedBillColor.withValues(
              alpha: .05,
            ), // Subtle highlight effect
            child: Column(
              children: [
                // Main content area with bill information
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Date and participants information
                      Expanded(
                        flex: 6, // 60% of horizontal space
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bill name
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 16,
                                  color: adjustedBillColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bill.billName,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: dateColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // Date line
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 14,
                                    color: participantsTextColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    bill.formattedDate,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: participantsTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Participants row with people icon
                            Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 16,
                                  color: participantsTextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bill.participantSummary, // Names or count of participants
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: participantsTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis, // Truncate with ... if too long
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Right side - Total amount in highlighted box
                      Expanded(
                        flex: 4, // 40% of horizontal space
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            // Background using bill color with appropriate opacity
                            color:
                                brightness == Brightness.dark
                                    ? adjustedBillColor.withValues(
                                      alpha: .15,
                                    ) // Higher opacity in dark mode
                                    : adjustedBillColor.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // "Total" label
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  // Text color uses bill color with opacity adjusted for theme
                                  color: adjustedBillColor.withValues(
                                    alpha:
                                        brightness == Brightness.dark
                                            ? 0.9
                                            : 0.8, // Brighter in dark mode
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Total amount with automatic scaling if too large
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  CurrencyFormatter.formatCurrency(bill.total),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: adjustedBillColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom action buttons with divider
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: dividerColor,
                        width: 1,
                      ), // Top border as divider
                    ),
                  ),
                  child: Row(
                    children: [
                      // "View" button
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.visibility_outlined,
                          label: 'View',
                          onTap: () => _navigateToBillDetails(context),
                          color: colorScheme.primary,
                        ),
                      ),

                      // Vertical divider between buttons
                      Container(width: 1, height: 24, color: dividerColor),

                      // "Delete" button
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          onTap:
                              () => _confirmDelete(
                                context,
                                colorScheme,
                                dialogBgColor,
                              ),
                          color:
                              colorScheme.error, // Use error color for delete
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a consistent action button for the bottom bar
  ///
  /// This helper method creates action buttons with consistent styling
  /// for the bottom of the card.
  ///
  /// Parameters:
  /// - context: The build context
  /// - icon: The icon to display
  /// - label: The button text
  /// - onTap: The callback function when button is tapped
  /// - color: The color for the icon and text
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a confirmation dialog and handles bill deletion
  ///
  /// This method shows a dialog asking the user to confirm deletion,
  /// then deletes the bill if confirmed and notifies the parent widget.
  ///
  /// Parameters:
  /// - context: The build context
  /// - colorScheme: The current theme's color scheme
  /// - dialogBgColor: The background color for the dialog
  Future<void> _confirmDelete(
    BuildContext context,
    ColorScheme colorScheme,
    Color dialogBgColor,
  ) async {
    // Provide haptic feedback when delete is tapped
    HapticFeedback.mediumImpact();

    // Show a confirmation dialog with custom styling
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: dialogBgColor,
            title: Row(
              children: [
                Icon(Icons.delete_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                const Text('Delete Bill'),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                16,
              ), // Rounded corners for dialog
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ), // Error color for delete
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    // If user confirmed, delete the bill and notify parent
    if (confirmed == true) {
      // Delete from persistent storage
      await RecentBillsManager.deleteBill(bill.id);

      // Provide haptic feedback for successful deletion
      HapticFeedback.mediumImpact();

      // Notify parent widget to refresh the list
      onDeleted();
    }
  }
}
