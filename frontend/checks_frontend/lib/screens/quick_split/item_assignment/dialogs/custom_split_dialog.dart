import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

void showCustomSplitDialog({
  required BuildContext context,
  required BillItem item,
  required List<Person> participants,
  required Function(BillItem, Map<Person, double>) onAssign,
  List<Person>? preselectedPeople,
  Person? birthdayPerson,
}) {
  // Initialize working assignments
  Map<Person, double> workingAssignments = {};

  // Get the participants we need to show
  List<Person> relevantParticipants =
      preselectedPeople != null && preselectedPeople.isNotEmpty
          ? preselectedPeople
          : participants;

  // Distribute evenly among preselected/all participants
  double evenShare = 100.0 / relevantParticipants.length;
  for (var person in participants) {
    workingAssignments[person] =
        relevantParticipants.contains(person) ? evenShare : 0.0;
  }

  // Calculate initial total
  double totalPercentage = 100.0;

  showDialog(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            // Get dominant color
            Color dominantColor = ColorUtils.getDominantColor(
              relevantParticipants,
            );

            // Get theme info
            final colorScheme = Theme.of(context).colorScheme;
            final brightness = Theme.of(context).brightness;

            // Theme-aware colors
            final dialogBgColor =
                brightness == Brightness.dark
                    ? colorScheme.surface
                    : Colors.white;

            final headerBgColor =
                brightness == Brightness.dark
                    ? ColorUtils.getDarkenedColor(
                      dominantColor,
                      0.7,
                    ).withOpacity(0.15)
                    : dominantColor.withOpacity(0.08);

            final textColor = colorScheme.onSurface;
            final subtitleColor =
                brightness == Brightness.dark
                    ? colorScheme.onSurface.withOpacity(0.7)
                    : Colors.grey.shade700;

            final bottomBarColor =
                brightness == Brightness.dark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white;

            final bottomBarShadowColor =
                brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.grey.shade200;

            final cancelButtonColor =
                brightness == Brightness.dark
                    ? colorScheme.outline.withOpacity(0.7)
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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with item details and total percentage
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
                          // Item name and price
                          Row(
                            children: [
                              Icon(
                                Icons.receipt,
                                size: 20,
                                color: dominantColor,
                              ),
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

                          // Total percentage indicator
                          Row(
                            children: [
                              // Status indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    totalPercentage,
                                    brightness,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      totalPercentage == 100.0
                                          ? Icons.check_circle
                                          : Icons.pie_chart,
                                      size: 16,
                                      color: _getStatusColor(
                                        totalPercentage,
                                        brightness,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Total: ${totalPercentage.toStringAsFixed(0)}%',
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

                              const SizedBox(width: 8),

                              // Normalize button (only show when needed)
                              if (totalPercentage != 100.0 &&
                                  totalPercentage > 0)
                                TextButton.icon(
                                  onPressed: () {
                                    setStateDialog(() {
                                      // Normalize to 100%
                                      double factor = 100.0 / totalPercentage;
                                      for (var person
                                          in workingAssignments.keys.toList()) {
                                        workingAssignments[person] =
                                            workingAssignments[person]! *
                                            factor;
                                      }
                                      totalPercentage = 100.0;
                                    });
                                    HapticFeedback.mediumImpact();
                                  },
                                  icon: const Icon(Icons.autorenew, size: 14),
                                  label: const Text(
                                    'Fix',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: dominantColor,
                                    backgroundColor: dominantColor.withOpacity(
                                      0.08,
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
                                ),

                              const Spacer(),

                              // Even split button
                              TextButton.icon(
                                onPressed: () {
                                  setStateDialog(() {
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
                                icon: const Icon(Icons.people, size: 14),
                                label: const Text(
                                  'Even',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: dominantColor,
                                  backgroundColor: dominantColor.withOpacity(
                                    0.08,
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
                              ),
                            ],
                          ),

                          // Progress bar
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalPercentage / 100,
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

                    // Participant sliders
                    Flexible(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        shrinkWrap: true,
                        itemCount: relevantParticipants.length,
                        itemBuilder: (context, index) {
                          final person = relevantParticipants[index];
                          final isBirthdayPerson = birthdayPerson == person;
                          final personColor =
                              isBirthdayPerson
                                  ? const Color(0xFF8E24AA) // Purple
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
                                workingAssignments[person] = value;
                                totalPercentage = workingAssignments.values
                                    .fold(0, (sum, value) => sum + value);
                              });
                              HapticFeedback.selectionClick();
                            },
                          );
                        },
                      ),
                    ),

                    // Actions
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

                          // Apply button - using a more theme-aware green
                          Expanded(
                            child: ElevatedButton(
                              // Find the code section in the showCustomSplitDialog function where the SnackBar is shown
                              // Replace this part in the onPressed callback of the Apply button:
                              onPressed:
                                  totalPercentage == 100.0
                                      ? () {
                                        Navigator.pop(context);
                                        onAssign(item, workingAssignments);

                                        // Show confirmation with theme-aware colors and consistent positioning
                                        final successColor =
                                            brightness == Brightness.dark
                                                ? const Color(
                                                  0xFF34D399,
                                                ) // Lighter green for dark mode
                                                : const Color(
                                                  0xFF10B981,
                                                ); // Original green for light mode

                                        // Get the top padding value to account for status bar height
                                        final topPadding =
                                            MediaQuery.of(context).padding.top;

                                        // First hide any current SnackBar
                                        ScaffoldMessenger.of(
                                          context,
                                        ).hideCurrentSnackBar();

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
                                            // Position the toast about 1/6 of the way down from the top of the screen
                                            margin: EdgeInsets.only(
                                              top:
                                                  topPadding +
                                                  60, // Move it down further from the top
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
                                      : null,
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
                                        ? Colors.black.withOpacity(
                                          0.9,
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

// Clean, space-efficient slider for each person
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

  // Theme-aware colors
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
          ? personColor.withOpacity(0.1)
          : personColor.withOpacity(0.03);

  final percentageBorderColor =
      brightness == Brightness.dark
          ? personColor.withOpacity(0.3)
          : personColor.withOpacity(0.12);

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
          ? personColor.withOpacity(0.5)
          : personColor.withOpacity(0.3);

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: containerBgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isActive ? personColor.withOpacity(0.3) : inactiveBorderColor,
        width: isActive ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Person info and percentage display
        Row(
          children: [
            // Avatar
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

            // Name and amount
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

            // Percentage badge
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

        // Row with slider and +/- buttons
        Row(
          children: [
            // Decrease button
            IconButton(
              onPressed:
                  percentage > 0
                      ? () {
                        // Decrement by 5%
                        onChanged(percentage - 5 < 0 ? 0 : percentage - 5);
                      }
                      : null,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              color: percentage > 0 ? personColor : inactiveButtonColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              splashRadius: 20,
            ),

            // Slider with theme-aware colors
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: personColor,
                  inactiveTrackColor:
                      brightness == Brightness.dark
                          ? personColor.withOpacity(
                            0.2,
                          ) // Brighter in dark mode
                          : personColor.withOpacity(0.1),
                  thumbColor: personColor,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                    elevation: 2,
                    pressedElevation: 4,
                  ),
                  overlayColor: personColor.withOpacity(0.2),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  showValueIndicator: ShowValueIndicator.always,
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                  valueIndicatorColor: personColor,
                  valueIndicatorTextStyle: TextStyle(
                    color:
                        brightness == Brightness.dark
                            ? Colors.black.withOpacity(
                              0.9,
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
                  divisions: 20, // 5% increments
                  label: '${percentage.toStringAsFixed(0)}%',
                  onChanged: onChanged,
                ),
              ),
            ),

            // Increase button
            IconButton(
              onPressed:
                  percentage < 100
                      ? () {
                        // Increment by 5%
                        onChanged(percentage + 5 > 100 ? 100 : percentage + 5);
                      }
                      : null,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              color: percentage < 100 ? personColor : inactiveButtonColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              splashRadius: 20,
            ),
          ],
        ),

        // Preset percentage buttons
        const SizedBox(height: 8),

        // Use SingleChildScrollView to prevent overflow
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                [0, 25, 50, 75, 100].map((presetValue) {
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
                                    ? Colors.black.withOpacity(0.9)
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
                                    : personColor.withOpacity(
                                      brightness == Brightness.dark ? 0.5 : 0.3,
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

// Get appropriate color based on percentage total and theme brightness
Color _getStatusColor(double percentage, Brightness brightness) {
  // Success green adjusted for dark mode
  final successGreen =
      brightness == Brightness.dark
          ? const Color(0xFF34D399) // Lighter green for dark mode
          : const Color(0xFF10B981); // Original green for light mode

  // Primary blue adjusted for dark mode
  final primaryBlue =
      brightness == Brightness.dark
          ? const Color(0xFF60A5FA) // Lighter blue for dark mode
          : const Color(0xFF3B82F6); // Original blue for light mode

  // Warning orange adjusted for dark mode
  final warningOrange =
      brightness == Brightness.dark
          ? const Color(0xFFFCD34D) // Lighter orange for dark mode
          : const Color(0xFFF97316); // Original orange for light mode

  if (percentage == 100.0) {
    return successGreen; // Success green
  } else if (percentage > 0) {
    return primaryBlue; // Primary blue
  } else {
    return warningOrange; // Warning orange
  }
}
