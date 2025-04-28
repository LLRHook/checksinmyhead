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

class _ItemCardState extends State<ItemCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  // Animation controller for button transitions
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  // Modern color palette
  static const Color slateGray = Color(0xFF64748B);
  static const Color lightSlateGray = Color(0xFF94A3B8);
  static const Color background = Color(0xFFF8FAFC);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final assignedPeople = widget.getAssignedPeopleForItem(widget.item);
    final defaultColor = Colors.grey.shade100;

    // Check if the selected person is already assigned to this item
    final bool isSelectedPersonAssigned = _isSelectedPersonAlreadyAssigned();

    // Determine if we need to show split option (when Y is selected and item is assigned to X)
    final bool canShowSplitOption =
        widget.selectedPerson != null &&
        assignedPeople.isNotEmpty &&
        !isSelectedPersonAssigned;

    // Use dominant person color for card background if there's only one assigned person
    Color backgroundColor;
    if (assignedPeople.length == 1) {
      // Use a very light tint of the person's color
      backgroundColor = _getLightenedColor(assignedPeople.first.color, 0.95);
    } else if (widget.selectedPerson != null &&
        !isSelectedPersonAssigned &&
        widget.assignedPercentage < 100.0) {
      // For unassigned items with a selected person, use a subtle hint of the person's color
      backgroundColor = _getLightenedColor(widget.selectedPerson!.color, 0.98);
    } else {
      backgroundColor = widget.getAssignmentColor(widget.item, defaultColor);
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
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
              // Single tap to expand/collapse or quick assign
              if (widget.selectedPerson != null &&
                  widget.assignedPercentage < 100.0 &&
                  !isSelectedPersonAssigned &&
                  assignedPeople.isEmpty) {
                // Quick assign for unassigned items when person is selected
                _assignToSelectedPerson();
                _showSuccessToast('Assigned to ${widget.selectedPerson!.name}');
              } else {
                // Otherwise toggle expanded state
                setState(() {
                  _isExpanded = !_isExpanded;
                });
                HapticFeedback.selectionClick();
              }
            },
            onLongPress: () {
              // Always expand on long press for better accessibility
              if (!_isExpanded) {
                setState(() {
                  _isExpanded = true;
                });
                HapticFeedback.mediumImpact();
              }
            },
            child: AnimatedCrossFade(
              firstChild: _buildCollapsedCard(
                colorScheme,
                assignedPeople,
                canShowSplitOption,
              ),
              secondChild: _buildExpandedCard(
                colorScheme,
                assignedPeople,
                canShowSplitOption,
              ),
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
      ),
    );
  }

  // Check if the selected person is already assigned to this item
  bool _isSelectedPersonAlreadyAssigned() {
    if (widget.selectedPerson == null) return false;

    // Check if the person is assigned to this item
    return widget.isPersonAssignedToItem(widget.item, widget.selectedPerson!);
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

  // Fully assign to selected person
  void _assignToSelectedPerson() {
    if (widget.selectedPerson == null) return;

    // Assign 100% to selected person
    Map<Person, double> newAssignments = {};
    for (var person in widget.participants) {
      newAssignments[person] = person == widget.selectedPerson ? 100.0 : 0.0;
    }
    widget.onAssign(widget.item, newAssignments);

    // Close expanded view and provide haptic feedback for successful assignment
    setState(() {
      _isExpanded = false;
    });
    HapticFeedback.mediumImpact();
  }

  // Split equally between current assignee and selected person
  void _splitWithCurrentAssignee() {
    if (widget.selectedPerson == null) return;

    final assignedPeople = widget.getAssignedPeopleForItem(widget.item);
    if (assignedPeople.isEmpty) return;

    // Create a list with both persons
    List<Person> splitBetween = [...assignedPeople];

    // Add selected person if not already in the list
    if (!splitBetween.contains(widget.selectedPerson)) {
      splitBetween.add(widget.selectedPerson!);
    }

    // Split evenly among these people
    widget.balanceItemBetweenAssignees(widget.item, splitBetween);

    // Close expanded view and provide feedback
    setState(() {
      _isExpanded = false;
    });

    // Show toast for the split action
    final names = splitBetween.map((p) => p.name).join(' & ');
    _showSuccessToast('Split between $names');

    HapticFeedback.mediumImpact();
  }

  // Also update the _removePersonAssignment method to ensure it handles the person removal properly
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

  // Simplify the toast notification by removing the UNDO functionality
  // Replace the _showSuccessToast method with this simplified version:

  void _showSuccessToast(String message) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();

    final Color backgroundColor =
        widget.selectedPerson != null
            ? _getDarkenedColor(widget.selectedPerson!.color, 0.1)
            : primaryBlue;
    final textColor = _getContrastiveTextColor(backgroundColor);

    scaffold.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: textColor, size: 18),
            const SizedBox(width: 10),
            // Use Expanded to prevent overflow with long text
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                // Allow text to wrap if needed (rarely happens in practice)
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
        // Removed the action parameter (UNDO button)
      ),
    );
  }

  // Helper to check if assignment is effectively complete (accounting for rounding errors)
  bool _isEffectivelyComplete(double percentage) {
    // Consider effectively complete if within 0.5% of 100%
    return percentage >= 99.5;
  }

  Widget _buildCollapsedCard(
    ColorScheme colorScheme,
    List<Person> assignedPeople,
    bool canShowSplitOption,
  ) {
    // Show assign indicator if a person is selected and item is not fully assigned
    // and the selected person is not already assigned to this item
    final bool showAssignIndicator =
        widget.selectedPerson != null &&
        widget.assignedPercentage < 100.0 &&
        !_isSelectedPersonAlreadyAssigned();

    return Stack(
      children: [
        Padding(
          // Increase horizontal padding slightly
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              // Item icon and name
              Icon(widget.universalItemIcon, color: slateGray, size: 20),
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
                        color: slateGray,
                      ),
                    ),
                    Text(
                      '\$${widget.item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: lightSlateGray,
                      ),
                    ),
                  ],
                ),
              ),

              // Assignment status with modern tags
              if (assignedPeople.isEmpty)
                _buildAssignmentTag(
                  'Unassigned',
                  warningOrange,
                  _getLightenedColor(warningOrange, 0.92),
                  Icons.person_off_outlined,
                )
              else if (widget.assignedPercentage == 100.0)
                _buildAssignmentTag(
                  'Assigned',
                  assignedPeople.length == 1
                      ? assignedPeople.first.color
                      : successGreen,
                  assignedPeople.length == 1
                      ? _getLightenedColor(assignedPeople.first.color, 0.92)
                      : _getLightenedColor(successGreen, 0.92),
                  Icons.check_circle_outline,
                )
              else
                _buildAssignmentTag(
                  '${widget.assignedPercentage.toStringAsFixed(0)}%',
                  primaryBlue,
                  _getLightenedColor(primaryBlue, 0.92),
                  Icons.percent_outlined,
                ),

              // Increase the spacing before avatars
              if (assignedPeople.isNotEmpty) ...[
                const SizedBox(width: 12),
                _buildAssigneeAvatars(assignedPeople),
              ],

              // Chevron/dropdown indicator
              const SizedBox(width: 8),
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: lightSlateGray,
              ),
            ],
          ),
        ),

        // Rest of the stack remains the same
        if (showAssignIndicator && assignedPeople.isEmpty)
          // Show plus indicator for quick assign
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
          )
        else if (canShowSplitOption)
          // Show split indicator for "split with" option
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade300,
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
    // Each avatar is 24px wide with 16px overlap, plus additional padding
    final double width =
        displayPeople.isEmpty ? 0.0 : 24.0 + (displayPeople.length - 1) * 16.0;
    final double extraWidth =
        assignedPeople.length > 3 ? 24.0 : 0.0; // For the +N avatar

    // Add additional padding to prevent clipping
    final double totalWidth = width + extraWidth + 4.0;

    return SizedBox(
      height: 24,
      width: totalWidth,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          for (int i = 0; i < displayPeople.length; i++)
            Positioned(
              right: i * 16.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
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
            ),
          if (assignedPeople.length > 3)
            Positioned(
              right: 3 * 16.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 12,
                  // Update the color to the specified one
                  backgroundColor: const Color(0xFF627D98),
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
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTag(
    String text,
    Color baseColor,
    Color backgroundColor,
    IconData icon,
  ) {
    final textColor =
        _isColorTooLight(backgroundColor)
            ? _getDarkenedColor(baseColor, 0.2)
            : baseColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCard(
    ColorScheme colorScheme,
    List<Person> assignedPeople,
    bool canShowSplitOption,
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

    // Check if the selected person is already assigned to this item
    final bool isSelectedPersonAssigned = _isSelectedPersonAlreadyAssigned();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with modern design
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getLightenedColor(primaryActionColor, 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.universalItemIcon,
                  color: primaryActionColor,
                  size: 20,
                ),
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
                        fontSize: 16,
                        color: slateGray,
                      ),
                    ),
                    Text(
                      '\$${widget.item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryActionColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Modern close button
              CloseButton(
                color: slateGray,
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                  });
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assignment Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: slateGray.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '${widget.assignedPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      // Use green color if percentage is close to 100% (to account for rounding)
                      color:
                          _isEffectivelyComplete(widget.assignedPercentage)
                              ? successGreen
                              : primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.assignedPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  // Use green color if percentage is close to 100% (to account for rounding)
                  color:
                      _isEffectivelyComplete(widget.assignedPercentage)
                          ? (assignedPeople.length == 1
                              ? primaryActionColor
                              : successGreen)
                          : primaryBlue,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Assignment options
        if (widget.selectedPerson != null) ...[
          // We have 3 cases:
          // 1. Unassigned item - show assign to X
          // 2. Item assigned to X and X is selected - show "already assigned"
          // 3. Item assigned to X and Y is selected - show "Split with X"
          if (!isSelectedPersonAssigned && assignedPeople.isEmpty) ...[
            // Case 1: Show assign button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildModernActionButton(
                label: 'Assign to ${widget.selectedPerson!.name}',
                icon: Icons.person_add,
                color: widget.selectedPerson!.color,
                onTap: _assignToSelectedPerson,
              ),
            ),
          ] else if (isSelectedPersonAssigned) ...[
            // Case 2: Show already assigned message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getLightenedColor(widget.selectedPerson!.color, 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getLightenedColor(
                      widget.selectedPerson!.color,
                      0.7,
                    ),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getLightenedColor(
                          widget.selectedPerson!.color,
                          0.8,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: widget.selectedPerson!.color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.selectedPerson!.name} is already assigned',
                            style: TextStyle(
                              color: _getDarkenedColor(
                                widget.selectedPerson!.color,
                                0.3,
                              ),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You can modify the split below',
                            style: TextStyle(
                              color: _getDarkenedColor(
                                widget.selectedPerson!.color,
                                0.2,
                              ).withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (canShowSplitOption) ...[
            // Case 3: Show split with X option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildModernActionButton(
                label:
                    'Split with ${assignedPeople.map((p) => p.name).join(' & ')}',
                icon: Icons.people,
                color: Colors.deepPurple.shade400,
                onTap: _splitWithCurrentAssignee,
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],

        // Action buttons with modern design
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              // Split evenly button
              Expanded(
                child: _buildModernButton(
                  label: 'Split Evenly',
                  icon: Icons.people_alt_outlined,
                  color: slateGray,
                  isOutlined: true,
                  onTap: () {
                    widget.onSplitEvenly(widget.item, widget.participants);
                    setState(() {
                      _isExpanded = false;
                    });
                    _showSuccessToast('Split evenly among all');
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Custom split button
              Expanded(
                child: _buildModernButton(
                  label: 'Custom Split',
                  icon: Icons.tune,
                  color: primaryActionColor,
                  isOutlined: false,
                  onTap: () {
                    widget.onShowCustomSplitDialog(
                      widget.item,
                      widget.getAssignedPeopleForItem(widget.item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        if (assignedPeople.isNotEmpty) ...[
          // Person's color-tinted divider
          Divider(height: 1, color: dividerColor, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fix for the Row overflow in the "Current Split" section
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Current Split',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: slateGray,
                        ),
                      ),
                    ),
                    if (widget.assignedPercentage < 100.0)
                      TextButton.icon(
                        onPressed: () {
                          widget.balanceItemBetweenAssignees(
                            widget.item,
                            assignedPeople,
                          );
                          _showSuccessToast('Split balanced');
                        },
                        icon: Icon(
                          Icons.balance,
                          size: 14,
                          color: primaryActionColor,
                        ),
                        label: Text(
                          'Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryActionColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 8, // Horizontal spacing between chips
                    runSpacing:
                        12, // Slightly increased vertical spacing for better readability
                    alignment: WrapAlignment.center, // Center align the chips
                    children:
                        assignedPeople.map((person) {
                          final percentage =
                              widget.item.assignments[person] ?? 0.0;
                          final amount = widget.item.price * percentage / 100;
                          return _buildModernPersonChip(
                            person: person,
                            percentage: percentage,
                            amount: amount,
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Completely fixed _buildModernPersonChip method with proper sizing for all elements
  Widget _buildModernPersonChip({
    required Person person,
    required double percentage,
    required double amount,
  }) {
    final backgroundColor = _getLightenedColor(person.color, 0.92);
    final borderColor = _getLightenedColor(person.color, 0.7);
    final textColor = _getDarkenedColor(person.color, 0.3);
    final deleteIconColor = _getDarkenedColor(person.color, 0.3);

    // Standard width for consistency
    const double standardChipWidth = 130.0;

    return GestureDetector(
      onTap: () => _showRemovePersonBottomSheet(person, percentage, amount),
      child: Container(
        width: standardChipWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: person.color.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // First row with avatar, name and delete button
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: person.color,
                  radius: 12,
                  child: Text(
                    person.name[0].toUpperCase(),
                    style: TextStyle(
                      color: _getContrastiveTextColor(person.color),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Name with fixed width and truncation
                Expanded(
                  child: Text(
                    person.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Delete button - always visible
                GestureDetector(
                  onTap: () {
                    _removePersonAssignment(person);
                    _showSuccessToast('Removed ${person.name}');
                  },
                  child: Icon(Icons.close, size: 16, color: deleteIconColor),
                ),
              ],
            ),

            // Second row with percentage and amount - FIXED TO PREVENT OVERFLOW
            Container(
              width: standardChipWidth - 24, // Account for horizontal padding
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Left padding to align with name
                  const SizedBox(width: 32),

                  // Percentage
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Middot and amount with truncation if needed
                  Expanded(
                    child: Text(
                      ' • \$${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The error is coming from a Row in the removal confirmation modal
  // Let's fix the _showRemovePersonBottomSheet method to handle long text properly

  void _showRemovePersonBottomSheet(
    Person person,
    double percentage,
    double amount,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                  // Handle
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                  ),

                  // Person avatar
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _getLightenedColor(person.color, 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: person.color,
                      child: Text(
                        person.name[0].toUpperCase(),
                        style: TextStyle(
                          color: _getContrastiveTextColor(person.color),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Confirmation message - truncate if too long
                  Text(
                    'Remove ${person.name}?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: slateGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Fix the overflow in this text section by wrapping it
                  Container(
                    width: double.infinity,
                    child: Text(
                      'This will remove ${person.name}\'s ${percentage.toStringAsFixed(0)}% share (\$${amount.toStringAsFixed(2)}) from this item.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: lightSlateGray,
                      ),
                      // Allow text to wrap if needed
                      softWrap: true,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                            foregroundColor: slateGray,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Remove button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _removePersonAssignment(person);
                            Navigator.pop(context);
                            _showSuccessToast('Removed ${person.name}');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: person.color,
                            foregroundColor: _getContrastiveTextColor(
                              person.color,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Remove',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
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
    );
  }

  // Modern action button with animation
  Widget _buildModernActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.mediumImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: _getLightenedColor(color, 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getLightenedColor(color, 0.7), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getLightenedColor(color, 0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _getDarkenedColor(color, 0.2),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: _getDarkenedColor(color, 0.2),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // Modern button with consistent styling
  Widget _buildModernButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isOutlined,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.mediumImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOutlined ? color : Colors.transparent,
            width: 1.5,
          ),
          boxShadow:
              isOutlined
                  ? null
                  : [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isOutlined ? color : _getContrastiveTextColor(color),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isOutlined ? color : _getContrastiveTextColor(color),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
