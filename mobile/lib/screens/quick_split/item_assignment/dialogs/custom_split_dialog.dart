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

//
// This module provides a dialog UI for custom splitting of bill items among participants.
// It allows users to manually adjust percentage allocations for each person with an
// intuitive slider interface that maintains a 100% total.
//
// Features:
// - Even distribution among participants
// - Individual percentage adjustment with sliders
// - Preset percentage buttons (0%, 25%, 50%, 75%, 100%)
// - Automatic total calculation and validation
// - Special handling for birthday people
// - Theme-aware styling (supports light and dark modes)
// - Normalize function to fix percentages when total is not 100%

import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

/// Shows a dialog for custom splitting of bill items among participants.
///
/// @param context The build context for showing the dialog
/// @param item The bill item to be split
/// @param participants All possible participants who can share the bill
/// @param onAssign Callback function when assignments are confirmed, receives updated item and assignments
/// @param preselectedPeople Optional list of pre-selected people for the split (defaults to all participants)
/// @param birthdayPerson Optional special person who gets visual highlighting (e.g., for birthday discounts)
///
/// The dialog allows percentage-based allocation of the bill item cost and validates
/// that the total equals 100% before allowing submission.
void showCustomSplitDialog({
  required BuildContext context,
  required BillItem item,
  required List<Person> participants,
  required Function(BillItem, Map<Person, double>) onAssign,
  List<Person>? preselectedPeople,
  Person? birthdayPerson,
}) {
  // Initialize working assignments map that will track percentage allocations
  Map<Person, double> workingAssignments = {};

  // Determine which participants to show in the dialog - either preselected or all
  List<Person> relevantParticipants =
      preselectedPeople != null && preselectedPeople.isNotEmpty
          ? preselectedPeople
          : participants;

  // Initially distribute the bill evenly among relevant participants
  double evenShare = 100.0 / relevantParticipants.length;
  for (var person in participants) {
    workingAssignments[person] =
        relevantParticipants.contains(person) ? evenShare : 0.0;
  }

  // Initial total should be 100%
  double totalPercentage = 100.0;

  showDialog(
    context: context,
    builder:
        (context) => StatefulBuilder(
          // StatefulBuilder allows the dialog to manage its own state
          builder: (context, setStateDialog) {
            // Get predominant color based on participant colors for theming
            Color dominantColor = ColorUtils.getDominantColor(
              relevantParticipants,
            );

            // Get the current theme information
            final colorScheme = Theme.of(context).colorScheme;
            final brightness = Theme.of(context).brightness;

            // Define theme-aware colors for different UI elements
            final dialogBgColor =
                brightness == Brightness.dark
                    ? colorScheme.surface
                    : Colors.white;

            final headerBgColor =
                brightness == Brightness.dark
                    ? ColorUtils.getDarkenedColor(
                      dominantColor,
                      0.7,
                    ).withValues(alpha: .15)
                    : dominantColor.withValues(alpha: .08);

            final textColor = colorScheme.onSurface;
            final subtitleColor =
                brightness == Brightness.dark
                    ? colorScheme.onSurface.withValues(alpha: .7)
                    : Colors.grey.shade700;

            final bottomBarColor =
                brightness == Brightness.dark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white;

            final bottomBarShadowColor =
                brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: .2)
                    : Colors.grey.shade200;

            final cancelButtonColor =
                brightness == Brightness.dark
                    ? colorScheme.outline.withValues(alpha: .7)
                    : Colors.grey.shade300;

            final cancelTextColor =
                brightness == Brightness.dark
                    ? colorScheme.onSurface
                    : Colors.grey.shade700;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              backgroundColor: dialogBgColor,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                // Constrain dialog size for better appearance on different screen sizes
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header section: Shows item details and percentage status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: headerBgColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item name and price display
                          Row(
                            children: [
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '\$${item.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Total percentage indicator with status color
                          Row(
                            children: [
                              // Visual indicator that changes color based on total percentage
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    totalPercentage,
                                    brightness,
                                  ).withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      totalPercentage == 100.0
                                          ? Icons
                                              .check_circle // Check mark when total is valid
                                          : Icons
                                              .pie_chart, // Pie chart when adjustments needed
                                      size: 16,
                                      color: _getStatusColor(
                                        totalPercentage,
                                        brightness,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${totalPercentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: _getStatusColor(
                                          totalPercentage,
                                          brightness,
                                        ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // "Even" button to reset to even distribution
                              TextButton(
                                onPressed: () {
                                  setStateDialog(() {
                                    // Reset to even distribution among relevant participants
                                    double evenShare =
                                        100.0 / relevantParticipants.length;
                                    for (var person in participants) {
                                      workingAssignments[person] =
                                          relevantParticipants.contains(person)
                                              ? evenShare
                                              : 0.0;
                                    }
                                    totalPercentage = 100.0;
                                  });
                                  HapticFeedback.mediumImpact();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: dominantColor,
                                  backgroundColor: dominantColor.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Split Evenly',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),

                          // Visual progress bar showing percentage completion
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    totalPercentage /
                                    100, // Normalized to 0.0-1.0 range
                                backgroundColor:
                                    brightness == Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getStatusColor(totalPercentage, brightness),
                                ),
                                minHeight: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable list of participants with their sliders
                    Flexible(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        shrinkWrap: true,
                        itemCount: relevantParticipants.length,
                        itemBuilder: (context, index) {
                          final person = relevantParticipants[index];
                          // Special color for birthday person
                          final isBirthdayPerson = birthdayPerson == person;
                          final personColor =
                              isBirthdayPerson
                                  ? const Color(
                                    0xFF8E24AA,
                                  ) // Purple for birthday
                                  : person.color;
                          final percentage = workingAssignments[person] ?? 0.0;

                          return _buildPersonSlider(
                            person: person,
                            percentage: percentage,
                            price: item.price,
                            personColor: personColor,
                            isBirthdayPerson: isBirthdayPerson,
                            brightness: brightness,
                            onChanged: (value) {
                              setStateDialog(() {
                                // Update this person's percentage
                                workingAssignments[person] = value;
                                // Recalculate the total
                                totalPercentage = workingAssignments.values
                                    .fold(0, (sum, value) => sum + value);
                              });
                              HapticFeedback.selectionClick();
                            },
                          );
                        },
                      ),
                    ),

                    // Bottom action buttons
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        color: bottomBarColor,
                        boxShadow: [
                          BoxShadow(
                            color: bottomBarShadowColor,
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Cancel button
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cancelTextColor,
                              side: BorderSide(color: cancelButtonColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),

                          const SizedBox(width: 12),

                          // Apply button - only enabled when total is 100%
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  totalPercentage == 100.0
                                      ? () {
                                        // Close dialog and call the assignment callback
                                        Navigator.pop(context);
                                        onAssign(item, workingAssignments);

                                        // Show success confirmation with theme-aware styling
                                        final successColor =
                                            brightness == Brightness.dark
                                                ? const Color(
                                                  0xFF34D399,
                                                ) // Lighter green for dark mode
                                                : const Color(
                                                  0xFF10B981,
                                                ); // Original green for light mode

                                        // Account for status bar height when positioning
                                        final topPadding =
                                            MediaQuery.of(context).padding.top;

                                        // Hide any existing SnackBar first
                                        ScaffoldMessenger.of(
                                          context,
                                        ).hideCurrentSnackBar();

                                        // Show success toast
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: GestureDetector(
                                              onTap: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).hideCurrentSnackBar();
                                              },
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'Split successfully applied',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            backgroundColor: successColor,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            // Position toast at a user-friendly location
                                            margin: EdgeInsets.only(
                                              top:
                                                  topPadding +
                                                  60, // Offset from top
                                              left: 16,
                                              right: 16,
                                              bottom:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height -
                                                  150 -
                                                  topPadding,
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      }
                                      : null, // Disabled when total is not 100%
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    brightness == Brightness.dark
                                        ? const Color(
                                          0xFF34D399,
                                        ) // Lighter green for dark mode
                                        : const Color(
                                          0xFF10B981,
                                        ), // Original green for light mode
                                foregroundColor:
                                    brightness == Brightness.dark
                                        ? Colors.black.withValues(
                                          alpha: 0.9,
                                        ) // Better contrast in dark mode
                                        : Colors.white,
                                disabledBackgroundColor:
                                    brightness == Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade300,
                                disabledForegroundColor:
                                    brightness == Brightness.dark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                elevation: totalPercentage == 100.0 ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              child: const Text(
                                'Apply Split',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

/// Builds a slider UI for a single person's percentage allocation.
///
/// @param person The person this slider controls
/// @param percentage Current percentage allocation (0-100)
/// @param price Total price of the item being split
/// @param personColor Theme color associated with this person
/// @param isBirthdayPerson Whether this person has birthday status
/// @param brightness Current theme brightness
/// @param onChanged Callback when percentage changes
///
/// @return A Widget containing the person's details, a slider for adjustment,
///         increment/decrement buttons, and preset percentage buttons
Widget _buildPersonSlider({
  required Person person,
  required double percentage,
  required double price,
  required Color personColor,
  required bool isBirthdayPerson,
  required Brightness brightness,
  required ValueChanged<double> onChanged,
}) {
  final isActive = percentage > 0;
  final individualAmount = (price * percentage / 100);

  // Theme-aware colors for UI elements
  final containerBgColor =
      brightness == Brightness.dark
          ? Color(0xFF1E1E1E) // Dark background for dark mode
          : Colors.white;

  final inactiveBorderColor =
      brightness == Brightness.dark
          ? Colors.grey.shade700
          : Colors.grey.shade200;

  final percentageColor =
      brightness == Brightness.dark
          ? ColorUtils.getLightenedColor(
            personColor,
            0.2,
          ) // Lighter in dark mode
          : personColor;

  final percentageBgColor =
      brightness == Brightness.dark
          ? personColor.withValues(alpha: .1)
          : personColor.withValues(alpha: .03);

  final percentageBorderColor =
      brightness == Brightness.dark
          ? personColor.withValues(alpha: .3)
          : personColor.withValues(alpha: .12);

  final textColor =
      brightness == Brightness.dark
          ? Colors
              .grey
              .shade300 // Lighter text in dark mode
          : Colors.grey.shade600;

  final nameColor =
      brightness == Brightness.dark
          ? ColorUtils.getLightenedColor(
            personColor,
            0.3,
          ) // Brighter in dark mode
          : personColor;

  final inactiveButtonColor =
      brightness == Brightness.dark
          ? personColor.withValues(alpha: .5)
          : personColor.withValues(alpha: .3);

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: containerBgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        // Highlight active selections with thicker border
        color:
            isActive ? personColor.withValues(alpha: .3) : inactiveBorderColor,
        width: isActive ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Person info section with avatar, name, amount and percentage
        Row(
          children: [
            // Avatar with first letter or cake icon for birthday
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: personColor,
              ),
              child: Center(
                child:
                    isBirthdayPerson
                        ? const Icon(Icons.cake, color: Colors.white, size: 16)
                        : Text(
                          person.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
              ),
            ),

            const SizedBox(width: 10),

            // Person name and their individual amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: nameColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '\$${individualAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ],
              ),
            ),

            // Current percentage badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: percentageBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: percentageBorderColor, width: 1),
              ),
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: percentageColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Interactive adjustment controls
        Row(
          children: [
            // Decrease button (1% increments)
            IconButton(
              onPressed:
                  percentage > 0
                      ? () {
                        // Decrement by 1% but don't go below 0
                        onChanged(percentage - 1 < 0 ? 0 : percentage - 1);
                      }
                      : null, // Disabled when already at 0%
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              color: percentage > 0 ? personColor : inactiveButtonColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              splashRadius: 20,
            ),

            // Percentage slider with custom theme
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: personColor,
                  inactiveTrackColor:
                      brightness == Brightness.dark
                          ? personColor.withValues(
                            alpha: 0.2,
                          ) // Brighter in dark mode
                          : personColor.withValues(alpha: .1),
                  thumbColor: personColor,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                    elevation: 2,
                    pressedElevation: 4,
                  ),
                  overlayColor: personColor.withValues(alpha: .2),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  showValueIndicator: ShowValueIndicator.always,
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                  valueIndicatorColor: personColor,
                  valueIndicatorTextStyle: TextStyle(
                    color:
                        brightness == Brightness.dark
                            ? Colors.black.withValues(
                              alpha: 0.9,
                            ) // Better contrast in dark mode
                            : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Slider(
                  value: percentage,
                  min: 0,
                  max: 100,
                  divisions: 100, // Creates 1% increments (100/100 = 1)
                  label: '${percentage.toStringAsFixed(0)}%',
                  onChanged: onChanged,
                ),
              ),
            ),

            // Increase button (1% increments)
            IconButton(
              onPressed:
                  percentage < 100
                      ? () {
                        // Increment by 1% but don't exceed 100
                        onChanged(percentage + 1 > 100 ? 100 : percentage + 1);
                      }
                      : null, // Disabled when already at 100%
              icon: const Icon(Icons.add_circle_outline, size: 18),
              color: percentage < 100 ? personColor : inactiveButtonColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              splashRadius: 20,
            ),
          ],
        ),

        // Quick preset percentage buttons
        const SizedBox(height: 8),

        // Horizontally scrollable preset buttons (0%, 25%, 50%, 75%, 100%)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                [0, 25, 50, 75, 100].map((presetValue) {
                  // Highlight the currently selected preset
                  final isSelected = (percentage - presetValue).abs() < 0.1;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton(
                      onPressed: () {
                        onChanged(presetValue.toDouble());
                        HapticFeedback.selectionClick();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isSelected
                                ? (brightness == Brightness.dark
                                    ? Colors.black.withValues(alpha: .9)
                                    : Colors.white)
                                : personColor,
                        backgroundColor:
                            isSelected ? personColor : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Colors.transparent
                                    : personColor.withValues(
                                      alpha:
                                          brightness == Brightness.dark
                                              ? 0.5
                                              : 0.3,
                                    ),
                            width: 1,
                          ),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '$presetValue%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    ),
  );
}

/// Determines the appropriate status color based on total percentage and theme.
///
/// @param percentage The current total percentage (0-100)
/// @param brightness The current theme brightness
/// @return A Color representing the status:
///   - Green: Total is exactly 100% (valid)
///   - Blue: Total is between 0% and 100% (in progress)
///   - Orange: Total is 0% (warning/empty)
Color _getStatusColor(double percentage, Brightness brightness) {
  // Define theme-aware colors for different statuses
  final successGreen =
      brightness == Brightness.dark
          ? const Color(0xFF34D399) // Lighter green for dark mode
          : const Color(0xFF10B981); // Original green for light mode

  final primaryBlue =
      brightness == Brightness.dark
          ? const Color(0xFF60A5FA) // Lighter blue for dark mode
          : const Color(0xFF3B82F6); // Original blue for light mode

  final warningOrange =
      brightness == Brightness.dark
          ? const Color(0xFFFCD34D) // Lighter orange for dark mode
          : const Color(0xFFF97316); // Original orange for light mode

  // Return color based on percentage
  if (percentage == 100.0) {
    return successGreen; // Ready to submit
  } else if (percentage > 0) {
    return primaryBlue; // In progress
  } else {
    return warningOrange; // No allocation yet
  }
}
