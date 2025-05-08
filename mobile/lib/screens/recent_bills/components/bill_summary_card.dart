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
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

/// BillSummaryCard
///
/// A reusable card widget that displays a detailed breakdown of a bill's financial components.
/// This widget presents a structured view of the bill's subtotal, tax, tip, and total amount
/// in a visually appealing card format that adapts to the current theme.
///
/// Features:
/// - Theme-aware styling that automatically adjusts for dark/light mode
/// - Professional card layout with header, content sections, and dividers
/// - Special formatting for the tip amount (shows percentage badge)
/// - Consistent spacing and alignment for readability
/// - Bold formatting for the total amount to emphasize the final cost
///
/// This component is designed to be easily integrated into bill detail screens
/// and requires a RecentBillModel to populate the financial data.
class BillSummaryCard extends StatelessWidget {
  /// The bill model containing the financial data to display
  final RecentBillModel bill;

  const BillSummaryCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors that adapt to light/dark mode
    // Card background - darker in dark mode, white in light mode
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    // Card border - subtle in both modes, more transparent in dark mode
    final cardBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .3)
            : Colors.grey.shade200;

    // Header background - uses primary container with appropriate opacity for each mode
    final headerBgColor =
        brightness == Brightness.dark
            ? colorScheme.primaryContainer.withValues(alpha: .15)
            : colorScheme.primaryContainer.withValues(alpha: .3);

    // Header text - uses primary color for both modes
    final headerTextColor = colorScheme.primary;

    // Divider color - subtle separator that works in both modes
    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .2)
            : Colors.grey.shade200;

    // Tip badge background - subtle highlight in primary color
    final tipBadgeBgColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .2)
            : colorScheme.primary.withValues(alpha: .1);

    // Text colors for regular content and total amount
    final textColor = colorScheme.onSurface;
    final totalTextColor = colorScheme.primary;

    return Card(
      elevation: 1, // Subtle elevation for depth
      surfaceTintColor: cardBgColor,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with title and icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: headerTextColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Bill Breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: headerTextColor,
                  ),
                ),
              ],
            ),
          ),

          // Bill details section with financial breakdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Subtotal row
                _buildDetailRow(
                  context,
                  'Subtotal',
                  bill.subtotal,
                  textColor: textColor,
                ),
                const SizedBox(height: 12),

                // Tax row
                _buildDetailRow(context, 'Tax', bill.tax, textColor: textColor),

                // Tip row - only shown if tip amount is greater than zero
                if (bill.tipAmount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tip', style: TextStyle(color: textColor)),
                      Row(
                        children: [
                          // Tip amount in currency format
                          Text(
                            CurrencyFormatter.formatCurrency(bill.tipAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Tip percentage badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tipBadgeBgColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${bill.tipPercentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                // Divider before total
                const SizedBox(height: 16),
                Divider(color: dividerColor),
                const SizedBox(height: 12),

                // Total row - emphasized with bold text and larger font
                _buildDetailRow(
                  context,
                  'Total',
                  bill.total,
                  isTotal: true, // Flag for special styling
                  textColor: totalTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build consistent row layout for bill details
  ///
  /// Creates a row with a label on the left and value on the right.
  /// The total row is styled differently with bold text and larger font size.
  ///
  /// Parameters:
  /// - context: The build context
  /// - label: The text label for the row (e.g., "Subtotal", "Tax")
  /// - value: The numerical value to display (formatted as currency)
  /// - isTotal: Whether this row represents the total amount (for special styling)
  /// - textColor: Optional color override for the text
  ///
  /// Returns a consistently styled row widget for the bill breakdown
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    double value, {
    bool isTotal = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label on the left side
        Text(
          label,
          style: TextStyle(
            // Make total label bold for emphasis
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            // Larger font for total
            fontSize: isTotal ? 16 : 14,
            color: textColor,
          ),
        ),

        // Value on the right side (formatted as currency)
        Text(
          CurrencyFormatter.formatCurrency(value),
          style: TextStyle(
            // All values are semi-bold, but total is full bold
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            // Larger font for total amount
            fontSize: isTotal ? 18 : 14,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
