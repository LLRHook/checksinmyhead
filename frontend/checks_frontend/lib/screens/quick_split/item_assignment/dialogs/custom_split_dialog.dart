import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

// Function to show the custom split dialog
void showCustomSplitDialog({
  required BuildContext context,
  required BillItem item,
  required List<Person> participants,
  required Function(BillItem, Map<Person, double>) onAssign,
  required IconData universalItemIcon,
  List<Person>? preselectedPeople,
}) {
  // Create a copy of current assignments to work with
  Map<Person, double> workingAssignments = Map.from(item.assignments);

  // If preselected people are provided, use them instead
  if (preselectedPeople != null && preselectedPeople.isNotEmpty) {
    workingAssignments = {};

    // Initialize all participants with 0%
    for (var person in participants) {
      workingAssignments[person] = 0.0;
    }

    // Distribute 100% evenly among preselected people
    double evenShare = 100.0 / preselectedPeople.length;
    for (var person in preselectedPeople) {
      workingAssignments[person] = evenShare;
    }
  } else {
    // Fill in missing participants with 0%
    for (var person in participants) {
      workingAssignments.putIfAbsent(person, () => 0.0);
    }
  }

  // Calculate total percentage assigned
  double totalPercentage = workingAssignments.values.fold(
    0,
    (sum, value) => sum + value,
  );

  showDialog(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          universalItemIcon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Split "${item.name}"',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '\$${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Total percentage indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color:
                            totalPercentage == 100.0
                                ? Colors.green.shade50
                                : totalPercentage > 100.0
                                ? Colors.red.shade50
                                : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              totalPercentage == 100.0
                                  ? Colors.green.shade200
                                  : totalPercentage > 100.0
                                  ? Colors.red.shade200
                                  : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            totalPercentage == 100.0
                                ? Icons.check_circle
                                : totalPercentage > 100.0
                                ? Icons.error
                                : Icons.info,
                            color:
                                totalPercentage == 100.0
                                    ? Colors.green.shade700
                                    : totalPercentage > 100.0
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total: ${totalPercentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        totalPercentage == 100.0
                                            ? Colors.green.shade800
                                            : totalPercentage > 100.0
                                            ? Colors.red.shade800
                                            : Colors.orange.shade800,
                                  ),
                                ),
                                if (totalPercentage != 100.0)
                                  Text(
                                    totalPercentage > 100.0
                                        ? 'Remove ${(totalPercentage - 100.0).toStringAsFixed(0)}% to balance'
                                        : 'Add ${(100.0 - totalPercentage).toStringAsFixed(0)}% to complete',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          totalPercentage > 100.0
                                              ? Colors.red.shade800
                                              : Colors.orange.shade800,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (totalPercentage > 0 && totalPercentage != 100.0)
                            TextButton(
                              onPressed: () {
                                setStateDialog(() {
                                  // Adjust values to make exactly 100%
                                  double currentTotal = workingAssignments
                                      .values
                                      .fold(0.0, (sum, value) => sum + value);

                                  if (currentTotal > 0) {
                                    double factor = 100.0 / currentTotal;

                                    for (var person
                                        in workingAssignments.keys.toList()) {
                                      double newValue =
                                          workingAssignments[person]! * factor;
                                      // Round to nearest 5%
                                      workingAssignments[person] =
                                          (newValue / 5).round() * 5;
                                    }

                                    // Adjust rounding errors
                                    var entries =
                                        workingAssignments.entries.toList()
                                          ..sort(
                                            (a, b) =>
                                                b.value.compareTo(a.value),
                                          );

                                    if (entries.isNotEmpty &&
                                        entries[0].value > 0) {
                                      double adjustedTotal = workingAssignments
                                          .values
                                          .fold(
                                            0.0,
                                            (sum, value) => sum + value,
                                          );

                                      double diff = 100.0 - adjustedTotal;
                                      workingAssignments[entries[0].key] =
                                          workingAssignments[entries[0].key]! +
                                          diff;
                                    }

                                    totalPercentage = 100.0;
                                  }
                                });
                              },
                              child: Text(
                                'Balance',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      totalPercentage > 100.0
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Person sliders
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final person = participants[index];
                          final percentage = workingAssignments[person] ?? 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: person.color,
                                      radius: 16,
                                      child: Text(
                                        person.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            person.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (percentage > 0)
                                            Text(
                                              '\$${(item.price * percentage / 100).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: person.color,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            percentage > 0
                                                ? person.color.withOpacity(0.1)
                                                : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              percentage > 0
                                                  ? person.color
                                                  : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                    // Quick presets
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setStateDialog(() {
                                          double newValue =
                                              (workingAssignments[person] ??
                                                  0) +
                                              25;
                                          workingAssignments[person] = newValue
                                              .clamp(0, 100);
                                          totalPercentage = workingAssignments
                                              .values
                                              .fold(0, (sum, val) => sum + val);
                                        });
                                        HapticFeedback.selectionClick();
                                      },
                                    ),
                                  ],
                                ),

                                // Percentage slider
                                Slider(
                                  value: percentage,
                                  min: 0,
                                  max: 100,
                                  divisions: 20,
                                  activeColor: person.color,
                                  inactiveColor: person.color.withOpacity(0.2),
                                  label: percentage.toStringAsFixed(0),
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      workingAssignments[person] = value;
                                      totalPercentage = workingAssignments
                                          .values
                                          .fold(0, (sum, val) => sum + val);
                                    });
                                  },
                                ),

                                // Percentage quick buttons
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children:
                                      [0, 25, 50, 75, 100].map((preset) {
                                        return ElevatedButton(
                                          onPressed: () {
                                            setStateDialog(() {
                                              workingAssignments[person] =
                                                  preset.toDouble();
                                              totalPercentage =
                                                  workingAssignments.values
                                                      .fold(
                                                        0,
                                                        (sum, val) => sum + val,
                                                      );
                                            });
                                            HapticFeedback.selectionClick();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            elevation: 0,
                                            backgroundColor:
                                                percentage == preset
                                                    ? person.color
                                                    : person.color.withOpacity(
                                                      0.1,
                                                    ),
                                            foregroundColor:
                                                percentage == preset
                                                    ? Colors.white
                                                    : person.color,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          child: Text(
                                            '$preset%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),

                                if (index < participants.length - 1)
                                  const Divider(height: 32),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            // Quick fix for minor rounding issues
                            if ((totalPercentage > 99.0 &&
                                    totalPercentage < 100.0) ||
                                (totalPercentage > 100.0 &&
                                    totalPercentage < 101.0)) {
                              // Adjust values to make exactly 100%
                              var entries = workingAssignments.entries.toList();
                              entries.sort(
                                (a, b) => b.value.compareTo(a.value),
                              );

                              if (entries.isNotEmpty && entries[0].value > 0) {
                                double diff = 100.0 - totalPercentage;
                                workingAssignments[entries[0].key] =
                                    workingAssignments[entries[0].key]! + diff;
                                totalPercentage = 100.0;
                              }
                            }

                            if (totalPercentage == 100.0) {
                              Navigator.pop(context);
                              onAssign(item, workingAssignments);
                            } else {
                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Total percentage must be 100%'),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                totalPercentage == 100.0
                                    ? Icons.check
                                    : Icons.warning,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                totalPercentage == 100.0
                                    ? 'Save'
                                    : 'Fix & Save',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}
