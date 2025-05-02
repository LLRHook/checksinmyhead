import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/participant_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

class ItemCard extends StatefulWidget {
  final BillItem item;
  final double assignedPercentage;
  final List<Person> participants;
  final List<Person> assignedPeople;
  final IconData universalItemIcon;
  final Function(BillItem, Map<Person, double>) onAssign;
  final Function(BillItem, List<Person>) onSplitEvenly;
  final Function(BillItem, List<Person>) onShowCustomSplit;
  final Person? birthdayPerson;
  final Function(Person) onBirthdayToggle;
  final double Function(Person) getPersonBillPercentage;

  const ItemCard({
    super.key,
    required this.item,
    required this.assignedPercentage,
    required this.participants,
    required this.assignedPeople,
    required this.onAssign,
    required this.onSplitEvenly,
    required this.onShowCustomSplit,
    required this.birthdayPerson,
    required this.universalItemIcon,
    required this.onBirthdayToggle,
    required this.getPersonBillPercentage,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _multiSelectMode = false;
  Set<Person> _selectedPeople = {};

  // Store original assignments for cancellation
  Map<Person, double>? _savedAssignmentsBeforeMultiSelect;

  // Animation controllers
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  // For card highlight animation
  bool _showHighlight = false;

  // Color constants - will be overridden with theme-aware colors
  static const Color slateGray = Color(0xFF64748B);
  static const Color lightSlateGray = Color(0xFF94A3B8);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5, // Half a turn (180 degrees)
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Listen for changes to assigned people
  @override
  void didUpdateWidget(ItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If assignment changed from unassigned to assigned, show highlight animation
    if (oldWidget.assignedPercentage == 0 && widget.assignedPercentage > 0) {
      _playHighlightAnimation();
    }
  }

  // Play a brief highlight effect when item is assigned
  void _playHighlightAnimation() {
    setState(() {
      _showHighlight = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showHighlight = false;
        });
      }
    });
  }

  // Toggle expansion state with animation
  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;

      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
    HapticFeedback.selectionClick();
  }

  // Handle single person assignment in normal mode
  void _handlePersonTap(Person person) {
    // Skip if this is a birthday person
    if (widget.birthdayPerson == person) return;

    if (_multiSelectMode) {
      // In multi-select mode, toggle selection
      _togglePersonSelection(person);
    } else {
      // In normal mode, assign 100% or remove
      _handleSinglePersonAssignment(person);
    }
  }

  // Toggle selection of a person in multi-select mode
  void _togglePersonSelection(Person person) {
    setState(() {
      if (_selectedPeople.contains(person)) {
        _selectedPeople.remove(person);
      } else {
        _selectedPeople.add(person);
      }
    });
    HapticFeedback.selectionClick();
  }

  // Handle single person assignment
  void _handleSinglePersonAssignment(Person person) {
    final isCurrentlyAssigned = widget.assignedPeople.contains(person);

    if (isCurrentlyAssigned) {
      // Remove this person's assignment
      Map<Person, double> newAssignments = {};

      // Copy current assignments excluding the person to remove
      for (var p in widget.participants) {
        final currentValue = widget.item.assignments[p] ?? 0.0;
        newAssignments[p] = p == person ? 0.0 : currentValue;
      }

      // If there are still people assigned, redistribute
      final remainingPeople =
          widget.assignedPeople.where((p) => p != person).toList();

      if (remainingPeople.isNotEmpty) {
        double totalRemaining = 0.0;
        for (var p in remainingPeople) {
          totalRemaining += newAssignments[p] ?? 0.0;
        }

        if (totalRemaining > 0) {
          // Scale factor to redistribute
          double scaleFactor = 100.0 / totalRemaining;

          // Rescale remaining people's percentages
          for (var p in remainingPeople) {
            newAssignments[p] = (newAssignments[p] ?? 0.0) * scaleFactor;
          }
        }
      }

      // Update assignments
      widget.onAssign(widget.item, newAssignments);
      HapticFeedback.mediumImpact();
      _showSuccessToast("Removed ${person.name}");
    } else {
      // In single-select mode, just assign 100% to this person
      Map<Person, double> newAssignments = {};
      for (var p in widget.participants) {
        newAssignments[p] = p == person ? 100.0 : 0.0;
      }

      // Update assignments
      widget.onAssign(widget.item, newAssignments);

      // Play assignment animation and haptic feedback
      _playHighlightAnimation();
      HapticFeedback.mediumImpact();
      _showSuccessToast("Assigned to ${person.name}");
    }
  }

  // Enter multi-select mode
  void _enterMultiSelectMode() {
    setState(() {
      _multiSelectMode = true;
      _selectedPeople.clear();

      // Save current assignments before clearing
      _savedAssignmentsBeforeMultiSelect = {};
      for (var person in widget.participants) {
        _savedAssignmentsBeforeMultiSelect![person] =
            widget.item.assignments[person] ?? 0.0;
      }

      // Clear all assignments
      Map<Person, double> clearAssignments = {};
      for (var p in widget.participants) {
        clearAssignments[p] = 0.0;
      }
      widget.onAssign(widget.item, clearAssignments);
    });
    HapticFeedback.mediumImpact();
  }

  // Cancel multi-select mode and restore assignments
  void _cancelMultiSelectMode() {
    if (_selectedPeople.isEmpty) {
      // Only restore if no selections were made
      _restoreOriginalAssignments();
    }

    setState(() {
      _multiSelectMode = false;
      _selectedPeople.clear();
    });

    HapticFeedback.mediumImpact();
  }

  // Restore original assignments
  void _restoreOriginalAssignments() {
    if (_savedAssignmentsBeforeMultiSelect != null) {
      // Restore the original assignments
      widget.onAssign(widget.item, _savedAssignmentsBeforeMultiSelect!);
      _savedAssignmentsBeforeMultiSelect = null; // Clear the saved state
    }
  }

  // Show custom split dialog with selected people
  void _showCustomSplitWithSelectedPeople() {
    if (_selectedPeople.isEmpty) {
      // Only check mounted status for showing the error SnackBar
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        final brightness = Theme.of(context).brightness;

        final snackBarBgColor =
            brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade700;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Select at least one person first'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: snackBarBgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Convert selected people to a list
    final selectedPeopleList = _selectedPeople.toList();

    // Store these variables locally before changing state
    final item = widget.item;
    final onShowCustomSplit = widget.onShowCustomSplit;

    // Close the expanded view and exit multi-select mode
    setState(() {
      _multiSelectMode = false;
      _selectedPeople.clear();
      _isExpanded = false;
      _animController.reverse();
    });

    // Call the callback to show the custom split dialog
    // Using the stored variables to ensure they're not accessed after state change
    onShowCustomSplit(item, selectedPeopleList);

    // Clear saved assignments since we've applied them
    _savedAssignmentsBeforeMultiSelect = null;
  }

  // Split evenly among all participants
  void _splitEvenlyAll() {
    widget.onSplitEvenly(widget.item, widget.participants);
    _playHighlightAnimation();
    _showSuccessToast('Split evenly among all');
  }

  // Show success toast
  void _showSuccessToast(String message) {
    // Check if the widget is still mounted before showing the toast
    if (!mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    final brightness = Theme.of(context).brightness;

    // Theme-aware success color
    final successToastColor =
        brightness == Brightness.dark
            ? const Color(0xFF34D399) // Lighter green for dark mode
            : const Color(0xFF10B981); // Original green

    scaffold.hideCurrentSnackBar();

    scaffold.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        backgroundColor: successToastColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Get dominant color with enhanced handling for dark mode
  Color getDominantColorForTheme(
    List<Person> assignedPeople,
    Brightness brightness,
  ) {
    Color baseColor = ColorUtils.getDominantColor(assignedPeople);

    // If we're in dark mode, significantly lighten the color (especially for purple)
    if (brightness == Brightness.dark) {
      // Special handling for purple hues which are particularly hard to see
      // Check if it's a purple or blue-purple color
      bool isPurplish = ColorUtils.isPurplish(baseColor);

      // Apply extra lightening for purplish colors in dark mode
      if (isPurplish) {
        return ColorUtils.getLightenedColor(
          baseColor,
          0.5,
        ); // 50% lighter for purple
      } else {
        return ColorUtils.getLightenedColor(
          baseColor,
          0.3,
        ); // 30% lighter for other colors
      }
    }

    return baseColor; // For light mode, use original color
  }

  @override
  Widget build(BuildContext context) {
    // Get theme info
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware color variables
    final Color themeSlateGray =
        brightness == Brightness.dark
            ? Color(0xFFA1A1AA) // Lighter slate for dark mode
            : slateGray;

    final Color themeLightSlateGray =
        brightness == Brightness.dark
            ? Color(0xFFD4D4D8) // Lighter gray for dark mode
            : lightSlateGray;

    final Color themePrimaryBlue =
        brightness == Brightness.dark
            ? Color(0xFF60A5FA) // Lighter blue for dark mode
            : primaryBlue;

    final Color themeSuccessGreen =
        brightness == Brightness.dark
            ? Color(0xFF34D399) // Lighter green for dark mode
            : successGreen;

    final Color themeWarningOrange =
        brightness == Brightness.dark
            ? Color(0xFFFCD34D) // Lighter orange for dark mode
            : warningOrange;

    // Get the dominant color for the card with enhanced dark mode handling
    Color dominantColor = getDominantColorForTheme(
      widget.assignedPeople,
      brightness,
    );
    bool isAssigned = widget.assignedPercentage > 0;
    bool isFullyAssigned = widget.assignedPercentage >= 99.5;

    // Background color for card - enhanced for dark mode
    final containerBgColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? ColorUtils.getDarkenedColor(dominantColor, 0.5).withOpacity(
                  0.4,
                ) // Less darkening, more opacity
                : colorScheme.surfaceContainerHighest)
            : (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.92)
                : Colors.white);

    // Border color for card - more visible in dark mode
    final containerBorderColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? dominantColor.withOpacity(
                  0.6,
                ) // Increase opacity for better visibility
                : colorScheme.outline.withOpacity(0.3))
            : (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.7)
                : Colors.grey.shade200);

    // Shadow color
    final shadowColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? dominantColor.withOpacity(0.2)
                : Colors.black.withOpacity(0.1))
            : (isAssigned
                ? dominantColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.03));

    // Highlight shadow color - enhanced for dark mode
    final highlightShadowColor =
        brightness == Brightness.dark
            ? dominantColor.withOpacity(0.7) // Stronger highlight in dark mode
            : dominantColor.withOpacity(0.3);

    // Icon background color - brighter in dark mode
    final iconBgColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.2).withOpacity(
                  0.4,
                ) // Much brighter
                : colorScheme.surfaceContainerHighest)
            : (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.85)
                : Colors.grey.shade100);

    // Title and price text colors - enhanced for readability
    final titleColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? ColorUtils.getLightenedColor(
                  dominantColor,
                  0.4,
                ) // Much brighter text
                : colorScheme.onSurface)
            : (isAssigned ? dominantColor : themeSlateGray);

    final priceColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? ColorUtils.getLightenedColor(
                  dominantColor,
                  0.2,
                ).withOpacity(0.9)
                : colorScheme.onSurface.withOpacity(0.7))
            : (isAssigned
                ? dominantColor.withOpacity(0.8)
                : themeLightSlateGray);

    // Divider color
    final dividerColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? dominantColor.withOpacity(
                  0.3,
                ) // Brighter divider in dark mode
                : colorScheme.outline.withOpacity(0.2))
            : (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.85)
                : Colors.grey.shade200);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: containerBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: containerBorderColor,
          width: isAssigned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          // Extra glow effect when item is newly assigned
          if (_showHighlight)
            BoxShadow(
              color: highlightShadowColor,
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            splashColor: dominantColor.withOpacity(0.05),
            highlightColor: dominantColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Item icon with assignment status indicator
                  Stack(
                    children: [
                      // Icon background
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow:
                              _showHighlight
                                  ? [
                                    BoxShadow(
                                      color: dominantColor.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Icon(
                          widget.universalItemIcon,
                          color: isAssigned ? dominantColor : themeSlateGray,
                          size: 22,
                        ),
                      ),

                      // Status indicator dot
                      if (isFullyAssigned)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: themeSuccessGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    brightness == Brightness.dark
                                        ? colorScheme.surface
                                        : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Item name and price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${widget.item.price.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, color: priceColor),
                        ),
                      ],
                    ),
                  ),

                  // Assignment status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status text
                      _buildAssignmentStatus(
                        isAssigned,
                        isFullyAssigned,
                        dominantColor,
                        themePrimaryBlue,
                        themeSuccessGreen,
                        themeWarningOrange,
                        brightness,
                      ),

                      const SizedBox(height: 4),

                      // Avatars or expand indicator
                      if (isAssigned && !_isExpanded)
                        _buildAssigneeAvatars()
                      else
                        RotationTransition(
                          turns: _rotateAnimation,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color:
                                isAssigned
                                    ? dominantColor
                                    : themeLightSlateGray,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded section with animation
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Divider
                  Divider(height: 1, thickness: 1, color: dividerColor),

                  // Participant selector with action buttons
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Use the participant selector component
                        ParticipantSelector(
                          participants: widget.participants,
                          assignedPeople: widget.assignedPeople,
                          selectedPeople: _selectedPeople,
                          birthdayPerson: widget.birthdayPerson,
                          onPersonTap: _handlePersonTap,
                          onBirthdayToggle: widget.onBirthdayToggle,
                          isMultiSelectMode: _multiSelectMode,
                        ),

                        const SizedBox(height: 16),

                        // Action buttons
                        _buildActionButtons(dominantColor, brightness),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build the assignment status tag
  Widget _buildAssignmentStatus(
    bool isAssigned,
    bool isFullyAssigned,
    Color dominantColor,
    Color themePrimaryBlue,
    Color themeSuccessGreen,
    Color themeWarningOrange,
    Brightness brightness,
  ) {
    // Theme-aware colors for status tags
    final unassignedBgColor =
        brightness == Brightness.dark
            ? themeWarningOrange.withOpacity(0.2)
            : themeWarningOrange.withOpacity(0.15);

    final fullyAssignedBgColor =
        brightness == Brightness.dark
            ? themeSuccessGreen.withOpacity(0.2)
            : themeSuccessGreen.withOpacity(0.15);

    final partiallyAssignedBgColor =
        brightness == Brightness.dark
            ? themePrimaryBlue.withOpacity(0.2)
            : themePrimaryBlue.withOpacity(0.15);

    if (!isAssigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: unassignedBgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Unassigned',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: themeWarningOrange,
          ),
        ),
      );
    } else if (isFullyAssigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fullyAssignedBgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Assigned',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: themeSuccessGreen,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: partiallyAssignedBgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${widget.assignedPercentage.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: themePrimaryBlue,
          ),
        ),
      );
    }
  }

  // Build the assignee avatars
  Widget _buildAssigneeAvatars() {
    if (widget.assignedPeople.isEmpty) return const SizedBox.shrink();

    // Limit to showing max 3 avatars
    final displayPeople =
        widget.assignedPeople.length > 3
            ? widget.assignedPeople.sublist(0, 3)
            : widget.assignedPeople;

    // Calculate a fixed width for the container
    final containerWidth =
        widget.assignedPeople.length > 3
            ? 4 * 12.0 +
                10.0 // 4 avatars at 12px spacing plus some buffer
            : displayPeople.length * 12.0 + 10.0;

    // Theme-aware colors
    final brightness = Theme.of(context).brightness;
    final borderColor =
        brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.white;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.1);

    final moreAvatarBgColor =
        brightness == Brightness.dark
            ? const Color(0xFF7F9DBA) // Lighter slate in dark mode
            : const Color(0xFF627D98);

    return SizedBox(
      height: 24,
      width: containerWidth, // Fixed width
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          for (int i = 0; i < displayPeople.length; i++)
            Positioned(
              right: i * 12.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: displayPeople[i].color,
                  child: Text(
                    displayPeople[i].name[0].toUpperCase(),
                    style: TextStyle(
                      color: ColorUtils.getContrastiveTextColor(
                        displayPeople[i].color,
                      ),
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            ),

          if (widget.assignedPeople.length > 3)
            Positioned(
              right: 3 * 12.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: moreAvatarBgColor,
                  child: Text(
                    '+${widget.assignedPeople.length - 3}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Action buttons with Multi-Split logic
  Widget _buildActionButtons(Color dominantColor, Brightness brightness) {
    // Theme-aware button colors
    final indigoGradient =
        brightness == Brightness.dark
            ? [
              const Color(0xFF818CF8), // Lighter indigo for dark mode
              const Color(0xFF6366F1),
            ]
            : [
              const Color(0xFF6366F1), // Normal indigo for light mode
              const Color(0xFF4F46E5),
            ];

    final greenGradient =
        brightness == Brightness.dark
            ? [
              const Color(0xFF34D399), // Lighter green for dark mode
              const Color(0xFF10B981),
            ]
            : [
              const Color(0xFF10B981), // Normal green for light mode
              const Color(0xFF059669),
            ];

    final slateGradient =
        brightness == Brightness.dark
            ? [
              const Color(0xFF94A3B8), // Lighter slate for dark mode
              const Color(0xFF64748B),
            ]
            : [
              const Color(0xFF64748B), // Normal slate for light mode
              const Color(0xFF475569),
            ];

    // For dominant color gradient, apply extra lightening in dark mode
    Color gradientStart, gradientEnd;
    if (brightness == Brightness.dark) {
      bool isPurplish = ColorUtils.isPurplish(dominantColor);
      double lightenFactor = isPurplish ? 0.5 : 0.3;

      gradientStart = ColorUtils.getLightenedColor(
        dominantColor,
        lightenFactor,
      );
      gradientEnd = dominantColor;
    } else {
      gradientStart = ColorUtils.getDarkenedColor(dominantColor, 0.1);
      gradientEnd = ColorUtils.getDarkenedColor(dominantColor, 0.3);
    }

    final dominantGradient = [gradientStart, gradientEnd];

    final cancelButtonBgColor =
        brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade200;

    final cancelButtonTextColor =
        brightness == Brightness.dark
            ? Colors.grey.shade300
            : Colors.grey.shade700;

    // Button text color - for dark mode, use darker text on bright backgrounds for better contrast
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(
              0.9,
            ) // Dark text for better contrast in dark mode
            : Colors.white;

    return Column(
      children: [
        // Main action buttons row
        Row(
          children: [
            // Split evenly button
            Expanded(
              child: _buildModernButton(
                label: 'Split Evenly',
                icon: Icons.people_alt_outlined,
                gradient: LinearGradient(
                  colors: indigoGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                textColor: buttonTextColor,
                onTap: _splitEvenlyAll,
              ),
            ),

            const SizedBox(width: 10),

            // Multi-split button
            Expanded(
              child:
                  _multiSelectMode
                      ? _buildModernButton(
                        label: 'Split It!',
                        icon: Icons.flash_on,
                        gradient: LinearGradient(
                          colors: greenGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor: buttonTextColor,
                        onTap: _showCustomSplitWithSelectedPeople,
                      )
                      : _buildModernButton(
                        label: 'Multi-Split',
                        icon: Icons.groups_outlined,
                        gradient: LinearGradient(
                          colors:
                              widget.assignedPeople.isNotEmpty
                                  ? dominantGradient
                                  : slateGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor: buttonTextColor,
                        onTap: _enterMultiSelectMode,
                      ),
            ),
          ],
        ),

        // Done/Cancel button
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GestureDetector(
            onTap: () {
              // If in multi-select mode, cancel it
              if (_multiSelectMode) {
                _cancelMultiSelectMode();
              }

              // Close the expanded view
              setState(() {
                _isExpanded = false;
                _animController.reverse();
              });
              HapticFeedback.mediumImpact();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cancelButtonBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _multiSelectMode ? 'Cancel' : 'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cancelButtonTextColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Button with gradient background
  Widget _buildModernButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.mediumImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
