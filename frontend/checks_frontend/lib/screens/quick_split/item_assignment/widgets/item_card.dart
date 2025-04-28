import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

class ItemCard extends StatefulWidget {
  final BillItem item;
  final double assignedPercentage;
  final Person? selectedPerson;
  final List<Person> participants;
  final IconData universalItemIcon;
  final Function(BillItem, Map<Person, double>) onAssign;
  final Function(BillItem, List<Person>) onSplitEvenly;
  final Function(BillItem, List<Person>) onShowCustomSplitDialog;
  final Color Function(BillItem, Color) getAssignmentColor;
  final bool Function(BillItem, Person) isPersonAssignedToItem;
  final List<Person> Function(BillItem) getAssignedPeopleForItem;
  final Function(BillItem, List<Person>) balanceItemBetweenAssignees;

  const ItemCard({
    super.key,
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
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _isExpanded = false;

  // Modern slate gray text color
  static const Color slateGray = Color(0xFF64748B);
  static const Color lightSlateGray = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final assignedPeople = widget.getAssignedPeopleForItem(widget.item);
    final defaultColor = Colors.grey.shade100;

    // Use dominant person color for card background if there's only one assigned person
    Color backgroundColor;
    if (assignedPeople.length == 1) {
      // Use a very light tint of the person's color
      backgroundColor = _getLightenedColor(assignedPeople.first.color, 0.95);
    } else {
      backgroundColor = widget.getAssignmentColor(widget.item, defaultColor);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              assignedPeople.length == 1
                  ? _getDarkenedColor(assignedPeople.first.color, 0.2)
                  : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // If a person is selected and card is tapped, assign the item directly
            if (widget.selectedPerson != null &&
                widget.assignedPercentage < 100.0) {
              _assignToSelectedPerson();
              HapticFeedback.selectionClick();
            } else {
              // Otherwise toggle expanded state
              setState(() {
                _isExpanded = !_isExpanded;
              });
              HapticFeedback.selectionClick();
            }
          },
          child: AnimatedCrossFade(
            firstChild: _buildCollapsedCard(colorScheme, assignedPeople),
            secondChild: _buildExpandedCard(colorScheme, assignedPeople),
            crossFadeState:
                _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            reverseDuration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOutCubic,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
          ),
        ),
      ),
    );
  }

  // Helper to get a lightened version of a color (more white)
  Color _getLightenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red + (255 - color.red) * factor).round(),
      (color.green + (255 - color.green) * factor).round(),
      (color.blue + (255 - color.blue) * factor).round(),
    );
  }

  // Helper to get a darkened version of a color
  Color _getDarkenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
    );
  }

  // Helper to determine if a color is too light for white text
  bool _isColorTooLight(Color color) {
    return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) /
            255 >
        0.7;
  }

  // Helper to get a contrastive text color (black or white) based on background
  Color _getContrastiveTextColor(Color backgroundColor) {
    return _isColorTooLight(backgroundColor) ? Colors.black : Colors.white;
  }

  void _assignToSelectedPerson() {
    if (widget.selectedPerson == null) return;

    // Assign 100% to selected person
    Map<Person, double> newAssignments = {};
    for (var person in widget.participants) {
      newAssignments[person] = person == widget.selectedPerson ? 100.0 : 0.0;
    }
    widget.onAssign(widget.item, newAssignments);
  }

  void _removePersonAssignment(Person person) {
    // Create new assignments map with the selected person removed
    Map<Person, double> newAssignments = {};

    // Copy current assignments
    for (var p in widget.participants) {
      final currentValue = widget.item.assignments[p] ?? 0.0;
      newAssignments[p] = p == person ? 0.0 : currentValue;
    }

    // Apply the updated assignments
    widget.onAssign(widget.item, newAssignments);

    // Provide haptic feedback for the removal action
    HapticFeedback.mediumImpact();
  }

  Widget _buildCollapsedCard(
    ColorScheme colorScheme,
    List<Person> assignedPeople,
  ) {
    // Show assign indicator if a person is selected and item is not fully assigned
    final bool showAssignIndicator =
        widget.selectedPerson != null && widget.assignedPercentage < 100.0;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Item icon and name
              Icon(
                widget.universalItemIcon,
                color: slateGray, // Modern slate gray
                size: 20,
              ),
              const SizedBox(width: 12),

              // Item name and price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: slateGray, // Modern slate gray
                      ),
                    ),
                    Text(
                      '\$${widget.item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: lightSlateGray, // Lighter slate gray
                      ),
                    ),
                  ],
                ),
              ),

              // Assignment status
              if (assignedPeople.isEmpty)
                _buildAssignmentTag(
                  'Unassigned',
                  Colors.orange.shade700,
                  Colors.orange.shade50,
                )
              else if (widget.assignedPercentage == 100.0)
                _buildAssignmentTag(
                  'Assigned',
                  assignedPeople.length == 1
                      ? assignedPeople.first.color
                      : Colors.green.shade700,
                  assignedPeople.length == 1
                      ? _getLightenedColor(assignedPeople.first.color, 0.85)
                      : Colors.green.shade50,
                )
              else
                _buildAssignmentTag(
                  '${widget.assignedPercentage.toStringAsFixed(0)}%',
                  Colors.blue.shade700,
                  Colors.blue.shade50,
                ),

              // Assigned people avatars
              if (assignedPeople.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildAssigneeAvatars(assignedPeople),
              ],

              // Chevron/dropdown indicator
              const SizedBox(width: 8),
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: lightSlateGray, // Lighter slate gray
              ),
            ],
          ),
        ),

        // Show simple plus indicator when item can be assigned to selected person
        if (showAssignIndicator)
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: _getDarkenedColor(widget.selectedPerson!.color, 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAssigneeAvatars(List<Person> assignedPeople) {
    // Limit to showing max 3 avatars
    final displayPeople =
        assignedPeople.length > 3
            ? assignedPeople.sublist(0, 3)
            : assignedPeople;

    // Calculate width based on number of avatars
    // Each avatar is 24px wide with 16px overlap
    final double width =
        displayPeople.isEmpty ? 0.0 : 24.0 + (displayPeople.length - 1) * 16.0;
    final double extraWidth =
        assignedPeople.length > 3 ? 24.0 : 0.0; // For the +N avatar

    return SizedBox(
      height: 24,
      width: width + extraWidth,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          for (int i = 0; i < displayPeople.length; i++)
            Positioned(
              right: i * 16.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: displayPeople[i].color,
                child: Text(
                  displayPeople[i].name[0].toUpperCase(),
                  style: TextStyle(
                    color: _getContrastiveTextColor(displayPeople[i].color),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          if (assignedPeople.length > 3)
            Positioned(
              right: 3 * 16.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey.shade700,
                child: const Text(
                  '+',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTag(
    String text,
    Color textColor,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildExpandedCard(
    ColorScheme colorScheme,
    List<Person> assignedPeople,
  ) {
    // Determine primary color for buttons and indicators
    Color primaryActionColor =
        assignedPeople.isNotEmpty
            ? assignedPeople.first.color
            : colorScheme.primary;

    // Ensure primary action color isn't too light
    if (_isColorTooLight(primaryActionColor)) {
      primaryActionColor = _getDarkenedColor(primaryActionColor, 0.2);
    }

    // Get divider color - a lighter tone of the primary color
    final dividerColor =
        assignedPeople.isNotEmpty
            ? _getLightenedColor(assignedPeople.first.color, 0.7)
            : Colors.grey.shade200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header - same as collapsed view but with close button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                widget.universalItemIcon,
                color: slateGray, // Modern slate gray
                size: 20,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: slateGray, // Modern slate gray
                      ),
                    ),
                    Text(
                      '\$${widget.item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: lightSlateGray, // Lighter slate gray
                      ),
                    ),
                  ],
                ),
              ),

              if (assignedPeople.isEmpty)
                _buildAssignmentTag(
                  'Unassigned',
                  Colors.orange.shade700,
                  Colors.orange.shade50,
                )
              else if (widget.assignedPercentage == 100.0)
                _buildAssignmentTag(
                  'Assigned',
                  assignedPeople.length == 1
                      ? assignedPeople.first.color
                      : Colors.green.shade700,
                  assignedPeople.length == 1
                      ? _getLightenedColor(assignedPeople.first.color, 0.85)
                      : Colors.green.shade50,
                )
              else
                _buildAssignmentTag(
                  '${widget.assignedPercentage.toStringAsFixed(0)}%',
                  Colors.blue.shade700,
                  Colors.blue.shade50,
                ),

              const SizedBox(width: 8),

              IconButton(
                icon: const Icon(Icons.expand_less, size: 20),
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                  });
                  HapticFeedback.selectionClick();
                },
                color: lightSlateGray, // Lighter slate gray
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: widget.assignedPercentage / 100,
            backgroundColor: Colors.grey.shade200,
            color:
                widget.assignedPercentage == 100.0
                    ? (assignedPeople.length == 1
                        ? primaryActionColor
                        : Colors.green)
                    : primaryActionColor,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(height: 16),

        // Assignment options
        if (widget.selectedPerson != null) ...[
          // Quick assign to selected person with improved color contrast
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _assignToSelectedPerson,
              icon: Icon(
                Icons.person,
                // Use a darker shade of the person's color for better contrast
                color: _getDarkenedColor(widget.selectedPerson!.color, 0.2),
                size: 18,
              ),
              label: Text(
                'Assign to ${widget.selectedPerson!.name}',
                style: TextStyle(
                  // Use a darker shade of the person's color for better contrast
                  color: _getDarkenedColor(widget.selectedPerson!.color, 0.2),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                // Use a very light shade of the person's color for the background
                backgroundColor: _getLightenedColor(
                  widget.selectedPerson!.color,
                  0.85,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              // Split evenly button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    widget.onSplitEvenly(widget.item, widget.participants);
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                  icon: const Icon(Icons.people_outline, size: 16),
                  label: const Text('Split Evenly'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: primaryActionColor),
                    foregroundColor: primaryActionColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Custom split button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onShowCustomSplitDialog(
                      widget.item,
                      widget.getAssignedPeopleForItem(widget.item),
                    );
                  },
                  icon: Icon(
                    Icons.tune,
                    size: 16,
                    color: _getContrastiveTextColor(primaryActionColor),
                  ),
                  label: Text(
                    'Custom Split',
                    style: TextStyle(
                      color: _getContrastiveTextColor(primaryActionColor),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryActionColor,
                    foregroundColor: _getContrastiveTextColor(
                      primaryActionColor,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Assigned people section
        if (assignedPeople.isNotEmpty) ...[
          // Person's color-tinted divider
          Divider(height: 1, color: dividerColor, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Split',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: slateGray, // Modern slate gray
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      assignedPeople.map((person) {
                        final percentage =
                            widget.item.assignments[person] ?? 0.0;
                        final amount = widget.item.price * percentage / 100;
                        return _buildInteractivePersonChip(
                          person: person,
                          percentage: percentage,
                          amount: amount,
                        );
                      }).toList(),
                ),
                const SizedBox(height: 8),
                if (widget.assignedPercentage < 100.0)
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        widget.balanceItemBetweenAssignees(
                          widget.item,
                          assignedPeople,
                        );
                      },
                      icon: Icon(
                        Icons.balance,
                        size: 16,
                        color: primaryActionColor,
                      ),
                      label: Text(
                        'Balance Split',
                        style: TextStyle(color: primaryActionColor),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryActionColor,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractivePersonChip({
    required Person person,
    required double percentage,
    required double amount,
  }) {
    // Get a lighter background and ensure text contrast
    final chipBackground = _getLightenedColor(person.color, 0.85);
    final textColor = _getDarkenedColor(person.color, 0.3);

    return GestureDetector(
      onTap: () {
        // Show a sleek confirmation before removal
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: person.color,
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: TextStyle(
                        color: _getContrastiveTextColor(person.color),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Remove ${person.name}?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: slateGray, // Modern slate gray
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This will remove ${person.name}\'s ${percentage.toStringAsFixed(0)}% share (\$${amount.toStringAsFixed(2)}) from this item.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: lightSlateGray, // Lighter slate gray
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                            foregroundColor: slateGray, // Modern slate gray
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _removePersonAssignment(person);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: person.color,
                            foregroundColor: _getContrastiveTextColor(
                              person.color,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getDarkenedColor(person.color, 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: person.color,
                  radius: 10,
                  child: Text(
                    person.name[0].toUpperCase(),
                    style: TextStyle(
                      color: _getContrastiveTextColor(person.color),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Subtle remove indicator
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: person.color, width: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              person.name,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${percentage.toStringAsFixed(0)}% • \$${amount.toStringAsFixed(2)}',
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
