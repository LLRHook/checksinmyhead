import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

class ItemCard extends StatelessWidget {
  final BillItem item;
  final double assignedPercentage;
  final Person? selectedPerson;
  final List<Person> participants;
  final IconData universalItemIcon;
  final Function(BillItem, Map<Person, double>) onAssign;
  final Function(BillItem, List<Person>) onSplitEvenly;
  final Function(BillItem item, List<Person> people) onShowCustomSplitDialog;
  final Function(BillItem, Color) getAssignmentColor;
  final Function(BillItem, Person) isPersonAssignedToItem;
  final Function(BillItem) getAssignedPeopleForItem;
  final Function(BillItem, List<Person>) balanceItemBetweenAssignees;

  const ItemCard({
    Key? key,
    required this.item,
    required this.assignedPercentage,
    required this.selectedPerson,
    required this.participants,
    required this.universalItemIcon,
    required this.onAssign,
    required this.onSplitEvenly,
    required this.onShowCustomSplitDialog,
    required this.getAssignmentColor,
    required this.isPersonAssignedToItem,
    required this.getAssignedPeopleForItem,
    required this.balanceItemBetweenAssignees,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.grey.shade300;
    Color backgroundColor = Colors.white;

    // Set color based on assignments
    if (assignedPercentage >= 100) {
      borderColor = Colors.green.withOpacity(0.5);
      backgroundColor = Colors.green.withOpacity(0.05);
    } else if (item.assignments.isNotEmpty) {
      // Use first person's color for partially assigned items
      var firstPerson = item.assignments.entries.first.key;
      borderColor = firstPerson.color.withOpacity(0.5);
      backgroundColor = firstPerson.color.withOpacity(0.05);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
          width: assignedPercentage >= 100 ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item header with icon, name and price
            _buildItemHeader(context),

            // Assignment progress indicator
            if (assignedPercentage > 0) _buildProgressIndicator(context),

            const SizedBox(height: 16),

            // Quick assign buttons
            _buildAssignButtonsRow(context),

            // Assignment indicators
            if (item.assignments.isNotEmpty) ...[
              const Divider(height: 24),

              Text(
                'Currently assigned to:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    item.assignments.entries.map((entry) {
                      final person = entry.key;
                      final percentage = entry.value;

                      return _buildAssignmentChip(context, person, percentage);
                    }).toList(),
              ),
            ],

            // Custom split option
            const SizedBox(height: 12),
            _buildCustomSplitButton(context),
          ],
        ),
      ),
    );
  }

  // Item header with name and price
  Widget _buildItemHeader(BuildContext context) {
    return Row(
      children: [
        // Item icon
        CircleAvatar(
          radius: 20,
          backgroundColor: getAssignmentColor(
            item,
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
          child: Icon(
            universalItemIcon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        // Item name and details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                assignedPercentage < 100
                    ? 'Who\'s this for? Select above.'
                    : '',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      assignedPercentage >= 100
                          ? Colors.green
                          : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        // Price
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '\$${item.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // Progress indicator
  Widget _buildProgressIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Assigned: ${assignedPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      assignedPercentage >= 100
                          ? Colors.green[700]
                          : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (assignedPercentage >= 100)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: assignedPercentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                assignedPercentage >= 100
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // Build smarter assign buttons row
  Widget _buildAssignButtonsRow(BuildContext context) {
    final bool isFullyAssigned = assignedPercentage >= 100;
    final List<Person> assignedPeople = getAssignedPeopleForItem(item);
    final bool selectedPersonIsAssigned =
        selectedPerson != null && isPersonAssignedToItem(item, selectedPerson!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Assign to selected person (if any)
            if (selectedPerson != null)
              Expanded(
                child: Builder(
                  builder: (context) {
                    // If selected person is already fully assigned to this item
                    if (selectedPersonIsAssigned &&
                        item.assignments[selectedPerson!] == 100.0) {
                      return ElevatedButton.icon(
                        onPressed: null, // Disabled button
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text('${selectedPerson!.name} assigned'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.grey.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                    // If item is already assigned to someone else and we need to split
                    else if (assignedPeople.isNotEmpty &&
                        !selectedPersonIsAssigned) {
                      return ElevatedButton.icon(
                        onPressed: () {
                          // Create custom split dialog with current assignees and selected person
                          List<Person> peopleToInclude = [
                            ...assignedPeople,
                            selectedPerson!,
                          ];
                          onShowCustomSplitDialog(item, peopleToInclude);
                        },
                        icon: const Icon(Icons.call_split, size: 18),
                        label: Text('Split with ${selectedPerson!.name}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedPerson!.color.withOpacity(
                            0.2,
                          ),
                          foregroundColor: selectedPerson!.color,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                    // Regular assign button for new assignment
                    else {
                      return ElevatedButton.icon(
                        onPressed:
                            isFullyAssigned
                                ? null
                                : () {
                                  onAssign(item, {selectedPerson!: 100.0});
                                },
                        icon: const Icon(Icons.person, size: 18),
                        label: Text('Assign to ${selectedPerson!.name}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedPerson!.color.withOpacity(
                            0.2,
                          ),
                          foregroundColor: selectedPerson!.color,
                          disabledBackgroundColor: Colors.grey.shade200,
                          disabledForegroundColor: Colors.grey.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

            // Split evenly button
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: selectedPerson != null ? 8.0 : 0.0,
                ),
                child: ElevatedButton.icon(
                  onPressed:
                      isFullyAssigned
                          ? null
                          : () {
                            onSplitEvenly(item, participants);
                          },
                  icon: const Icon(Icons.groups, size: 18),
                  label: const Text('Split Evenly'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // If item is partially assigned but not fully assigned,
        // show a button to split between current assignees
        if (assignedPeople.length > 1 && assignedPercentage < 100)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                balanceItemBetweenAssignees(item, assignedPeople);
              },
              icon: const Icon(Icons.balance, size: 18),
              label: const Text('Balance Between Current People'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.withOpacity(0.2),
                foregroundColor: Colors.amber.shade800,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Build custom split button
  Widget _buildCustomSplitButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        onShowCustomSplitDialog(item, []);
      },
      icon: const Icon(Icons.pie_chart, size: 18),
      label: const Text('Custom Split'),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Build assignment chip
  Widget _buildAssignmentChip(
    BuildContext context,
    Person person,
    double percentage,
  ) {
    return InputChip(
      label: Text('${person.name} (${percentage.toStringAsFixed(0)}%)'),
      backgroundColor: person.color.withOpacity(0.2),
      side: BorderSide(color: person.color.withOpacity(0.3)),
      labelStyle: TextStyle(color: person.color, fontWeight: FontWeight.w500),
      avatar: CircleAvatar(
        backgroundColor: person.color,
        child: Text(
          person.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () {
        // Create a new assignments map without this person
        final newAssignments = Map<Person, double>.from(item.assignments);
        newAssignments.remove(person);

        // If there are still people assigned, rebalance to 100%
        if (newAssignments.isNotEmpty) {
          double remainingPercentage = newAssignments.values.fold(
            0.0,
            (sum, value) => sum + value,
          );

          if (remainingPercentage > 0) {
            double factor = 100.0 / remainingPercentage;
            newAssignments.forEach((key, value) {
              newAssignments[key] = value * factor;
            });
          }
        }

        onAssign(item, newAssignments);
      },
    );
  }
}
