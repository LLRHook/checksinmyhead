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

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
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
                        color: dominantColor.withOpacity(0.08),
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
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '\$${item.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
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
                                      color: _getStatusColor(totalPercentage),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Total: ${totalPercentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: _getStatusColor(totalPercentage),
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
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getStatusColor(totalPercentage),
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
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
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
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
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

                          // Apply button
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  totalPercentage == 100.0
                                      ? () {
                                        Navigator.pop(context);
                                        onAssign(item, workingAssignments);

                                        // Show confirmation
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Split successfully applied',
                                            ),
                                            backgroundColor: const Color(
                                              0xFF10B981,
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      }
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade600,
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
  required ValueChanged<double> onChanged,
}) {
  final isActive = percentage > 0;
  final individualAmount = (price * percentage / 100);

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isActive ? personColor.withOpacity(0.3) : Colors.grey.shade200,
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
                      color: personColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '\$${individualAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Percentage badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: personColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: personColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: personColor,
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
              color: personColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              splashRadius: 20,
            ),

            // Slider
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: personColor,
                  inactiveTrackColor: personColor.withOpacity(0.1),
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
                  valueIndicatorTextStyle: const TextStyle(
                    color: Colors.white,
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
              color: personColor,
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
                            isSelected ? Colors.white : personColor,
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
                                    : personColor.withOpacity(0.3),
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

// Get appropriate color based on percentage total
Color _getStatusColor(double percentage) {
  if (percentage == 100.0) {
    return const Color(0xFF10B981); // Success green
  } else if (percentage > 0) {
    return const Color(0xFF3B82F6); // Primary blue
  } else {
    return const Color(0xFFF97316); // Warning orange
  }
}
