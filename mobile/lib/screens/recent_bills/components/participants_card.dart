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
import 'package:checks_frontend/screens/recent_bills/billDetails/utils/bill_calculations.dart';
import 'package:flutter/material.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

/// ParticipantsCard
///
/// A sophisticated card widget that displays all participants in a bill along with
/// their individual payment breakdowns. This component provides an expandable view
/// with detailed information about each participant's assigned items and costs.
///
/// Features:
/// - Displays all participants with their total payment amounts
/// - Expandable sections showing detailed item breakdowns for each person
/// - Visual indicators for shared items (with percentage badges)
/// - Theme-aware styling that adapts to light/dark mode
/// - Automatic state management for expansion panels
///
/// This component is a core part of the bill details screen, providing a comprehensive
/// overview of how costs are distributed among participants.
class ParticipantsCard extends StatefulWidget {
  /// The bill model containing participant and item data
  final RecentBillModel bill;

  /// Pre-calculated bill data to avoid redundant calculations
  final BillCalculations calculations;

  const ParticipantsCard({
    super.key,
    required this.bill,
    required this.calculations,
  });

  @override
  State<ParticipantsCard> createState() => _ParticipantsCardState();
}

class _ParticipantsCardState extends State<ParticipantsCard> {
  /// Track the expansion state of each participant panel
  /// Map keys are participant names, values are boolean expansion states
  final Map<String, bool> _expansionState = {};

  @override
  void initState() {
    super.initState();

    // Initialize expansion state - first participant expanded by default
    if (widget.bill.participantNames.isNotEmpty) {
      _expansionState[widget.bill.participantNames[0]] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme data for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Get pre-calculated person totals from the BillCalculations utility
    final personTotals = widget.calculations.calculatePersonTotals();

    // Check if bill has custom item assignments or uses equal splitting
    final hasRealAssignments = widget.calculations.hasRealAssignments();
    final equalShare = widget.calculations.calculateEqualShare();

    // Define theme-aware colors that adapt to light/dark mode
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .3)
            : Colors.grey.shade200;

    final headerBgColor =
        brightness == Brightness.dark
            ? colorScheme.primaryContainer.withValues(alpha: .15)
            : colorScheme.primaryContainer.withValues(alpha: .3);

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .2)
            : Colors.grey.shade200;

    final tileBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final subtitleColor =
        brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600];

    final amountBgColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .2)
            : colorScheme.primaryContainer.withValues(alpha: .7);

    final viewDetailsColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .8)
            : colorScheme.primary.withValues(alpha: .7);

    final sectionHeaderColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .8)
            : colorScheme.onSurface.withValues(alpha: .7);

    final bulletColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(alpha: .7)
            : colorScheme.primary.withValues(alpha: .5);

    final percentageBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: .6)
            : colorScheme.surfaceContainerHighest;

    return Card(
      elevation: 1,
      surfaceTintColor: cardBgColor,
      margin: EdgeInsets.zero,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header with title and participant count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Participants',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // Participant count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.bill.participantCount}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expandable list of participants
          ListView.builder(
            shrinkWrap: true, // Use only the space needed
            physics:
                const NeverScrollableScrollPhysics(), // Disable scrolling within this list
            itemCount: widget.bill.participantNames.length,
            itemBuilder: (context, index) {
              final name = widget.bill.participantNames[index];
              // Get expansion state for this participant
              final isExpanded = _expansionState[name] ?? false;

              // Calculate amounts for this person
              // Use pre-calculated totals or fallback to equal share if no assignments exist
              final totalAmount =
                  hasRealAssignments ? (personTotals[name] ?? 0.0) : equalShare;

              // Get tax and tip portion for this person
              final taxAndTipAmount =
                  widget.calculations.calculatePersonTaxAndTip()[name] ?? 0.0;

              // Extract items this person is paying for from the bill data
              List<Map<String, dynamic>> personItems = [];
              if (widget.bill.items != null) {
                for (var item in widget.bill.items!) {
                  final itemName = item['name'] as String? ?? 'Unknown Item';
                  final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                  final assignments =
                      item['assignments'] as Map<String, dynamic>?;

                  // If this person has an assignment for this item
                  if (assignments != null && assignments.containsKey(name)) {
                    final percentage = assignments[name] as num;
                    if (percentage > 0) {
                      // Only include if percentage is positive
                      final itemAmount = price * percentage / 100;
                      // Flag as shared if percentage < 100
                      final isShared = percentage < 100;
                      personItems.add({
                        'name': itemName,
                        'price': itemAmount,
                        'percentage': percentage,
                        'isShared': isShared,
                      });
                    }
                  }
                }
              }

              // Sort items by price (highest first) for better UX
              personItems.sort(
                (a, b) =>
                    (b['price'] as double).compareTo(a['price'] as double),
              );

              // Build the expansion tile for this participant
              return Column(
                children: [
                  // Add a divider before each participant except the first one
                  if (index > 0)
                    Divider(color: dividerColor, height: 1, thickness: 1),

                  // Wrap in Theme to remove the default expansion tile divider
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      backgroundColor: tileBgColor,
                      collapsedBackgroundColor: tileBgColor,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.only(
                        left: 56, // Aligns child content with the title text
                        right: 16,
                        bottom: 16,
                      ),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      maintainState:
                          true, // Keep state when collapsed for better performance
                      initiallyExpanded:
                          index == 0, // First participant expanded by default
                      onExpansionChanged: (expanded) {
                        // Update the expansion state when toggled
                        setState(() {
                          _expansionState[name] = expanded;
                        });
                      },

                      // Avatar with first letter of participant's name
                      leading: CircleAvatar(
                        backgroundColor: ColorUtils.getPersonColor(
                          index,
                          colorScheme,
                          brightness,
                        ),
                        radius: 20,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Participant's name
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      // Item count as subtitle (only if they have items)
                      subtitle:
                          personItems.isNotEmpty
                              ? Text(
                                '${personItems.length} item(s)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              )
                              : null,

                      // Total amount and expand/collapse indicator
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Total amount in a badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: amountBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              CurrencyFormatter.formatCurrency(totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),

                          // Animated chevron (only if they have items)
                          if (personItems.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.expand_more,
                                  color: viewDetailsColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Expanded content showing item breakdown
                      children: [
                        // Items section
                        if (personItems.isNotEmpty) ...[
                          // Items header
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Text(
                              'Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: sectionHeaderColor,
                              ),
                            ),
                          ),

                          // List of items this person is paying for
                          ...personItems.map(
                            (item) => _buildItemRow(
                              context,
                              item['name'] as String,
                              item['price'] as double,
                              item['percentage'] as num,
                              colorScheme,
                              bulletColor,
                              percentageBgColor,
                            ),
                          ),
                        ],

                        // Tax & Tip section (only shown if non-zero)
                        if (taxAndTipAmount > 0) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Row(
                              children: [
                                // Tax & Tip label
                                Text(
                                  'Tax & Tip',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: sectionHeaderColor,
                                  ),
                                ),

                                const Spacer(), // Push amount to right side
                                // Tax & Tip amount
                                Text(
                                  CurrencyFormatter.formatCurrency(
                                    taxAndTipAmount,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: sectionHeaderColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds a row displaying an individual item with its price and percentage
  ///
  /// This helper method creates a consistent item row for the expanded details
  /// section, showing the item name, amount, and percentage badge if applicable.
  ///
  /// Parameters:
  /// - context: The build context
  /// - name: The name of the item
  /// - amount: The amount this person is paying for the item
  /// - percentage: The percentage of the item assigned to this person
  /// - colorScheme: The current theme's color scheme
  /// - bulletColor: The color for the bullet point
  /// - percentageBgColor: The background color for the percentage badge
  Widget _buildItemRow(
    BuildContext context,
    String name,
    double amount,
    num percentage,
    ColorScheme colorScheme,
    Color bulletColor,
    Color percentageBgColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 14),

          // Bullet point indicator
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Item name
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          // Amount and percentage section
          Row(
            children: [
              // Formatted currency amount
              Text(
                CurrencyFormatter.formatCurrency(amount),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),

              // Percentage badge - only shown for shared items (less than 100%)
              if (percentage < 100) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: percentageBgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${percentage.toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
