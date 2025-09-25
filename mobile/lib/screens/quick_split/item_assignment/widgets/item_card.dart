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

import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/participant_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';

/// An interactive card widget that displays a bill item and allows users to assign
/// it to one or more participants in different ways.
///
/// This widget provides a rich UI for bill item assignment with features including:
/// - Visual indication of assignment status (unassigned, partially assigned, fully assigned)
/// - Single-tap assignment to individual people
/// - Multi-select mode for assigning to multiple people simultaneously
/// - Split-evenly functionality for quick fair divisions
/// - Custom split option for precise percentage assignments
/// - Special handling for birthday people who are exempt from payment
/// - Animations and haptic feedback for an engaging user experience
/// - Adaptive theming for both light and dark modes
///
/// The card has both collapsed and expanded states, with the expanded state
/// revealing participant selection and action buttons.
class ItemCard extends StatefulWidget {
  /// The bill item being displayed and assigned
  final BillItem item;

  /// Current percentage of the item that has been assigned (0-100)
  final double assignedPercentage;

  /// List of all available participants in the bill
  final List<Person> participants;

  /// List of people currently assigned to this item
  final List<Person> assignedPeople;

  /// Icon to display for this item
  final IconData universalItemIcon;

  /// Callback when assignments are updated with new percentages
  final Function(BillItem, Map<Person, double>) onAssign;

  /// Callback to split item evenly among specified people
  final Function(BillItem, List<Person>) onSplitEvenly;

  /// Callback to show custom split UI for precise percentage assignment
  final Function(BillItem, List<Person>) onShowCustomSplit;

  /// Person who is celebrating their birthday (exempt from payment)
  final Person? birthdayPerson;

  /// Callback to toggle birthday status for a person
  final Function(Person) onBirthdayToggle;

  /// Function to calculate what percentage of the total bill a person is responsible for
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
  /// Whether the card is in expanded state showing participant selector
  bool _isExpanded = false;

  /// Whether multi-select mode is active for selecting multiple participants
  bool _multiSelectMode = false;

  /// Set of people selected in multi-select mode
  final Set<Person> _selectedPeople = {};

  /// Store original assignments to restore if multi-select is cancelled
  Map<Person, double>? _savedAssignmentsBeforeMultiSelect;

  // Animation controllers and animations
  /// Controller for all animations
  late AnimationController _animController;

  /// Animation for the expand/collapse effect
  late Animation<double> _expandAnimation;

  /// Animation for rotating the expand/collapse arrow
  late Animation<double> _rotateAnimation;

  /// Animation for fading in the expanded content
  late Animation<double> _fadeAnimation;

  /// Whether to show highlight effect when item is newly assigned
  bool _showHighlight = false;

  // Color constants - theme-aware versions are calculated in build method
  /// Default slate gray for neutral elements
  static const Color slateGray = Color(0xFF64748B);

  /// Lighter slate gray for secondary text
  static const Color lightSlateGray = Color(0xFF94A3B8);

  /// Primary blue for partially assigned items
  static const Color primaryBlue = Color(0xFF3B82F6);

  /// Success green for fully assigned items
  static const Color successGreen = Color(0xFF10B981);

  /// Warning orange for unassigned items
  static const Color warningOrange = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    // Initialize animation controller with moderate duration
    _animController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Create expand animation with easing for natural motion
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    // Create rotation animation for the dropdown arrow (180 degrees)
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5, // Half a turn (180 degrees)
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    // Create fade animation with delay for sequential appearance
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up animation controller to prevent memory leaks
    _animController.dispose();
    super.dispose();
  }

  /// Detect assignment changes to trigger highlight animation
  @override
  void didUpdateWidget(ItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If assignment changed from unassigned to assigned, show highlight animation
    if (oldWidget.assignedPercentage == 0 && widget.assignedPercentage > 0) {
      _playHighlightAnimation();
    }
  }

  /// Play a brief highlight effect when an item is newly assigned
  ///
  /// Creates a momentary glow effect around the card to provide visual feedback
  void _playHighlightAnimation() {
    setState(() {
      _showHighlight = true;
    });

    // Remove highlight after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showHighlight = false;
        });
      }
    });
  }

  /// Toggle between expanded and collapsed states with animation
  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;

      // Run the appropriate animation based on new state
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
    // Provide tactile feedback
    HapticFeedback.selectionClick();
  }

  /// Handle taps on a person in either normal or multi-select mode
  ///
  /// In normal mode: Toggle 100% assignment to the person
  /// In multi-select mode: Add/remove person from selection
  void _handlePersonTap(Person person) {
    // Skip if this is the birthday person (who doesn't pay)
    if (widget.birthdayPerson == person) return;

    if (_multiSelectMode) {
      // In multi-select mode, toggle selection status
      _togglePersonSelection(person);
    } else {
      // In normal mode, assign 100% or remove assignment
      _handleSinglePersonAssignment(person);
    }
  }

  /// Add or remove a person from the selection in multi-select mode
  void _togglePersonSelection(Person person) {
    setState(() {
      if (_selectedPeople.contains(person)) {
        _selectedPeople.remove(person);
      } else {
        _selectedPeople.add(person);
      }
    });
    // Provide tactile feedback
    HapticFeedback.selectionClick();
  }

  /// Handle assignment when a single person is tapped in normal mode
  ///
  /// If person is already assigned: Remove their assignment and redistribute
  /// If person is not assigned: Assign 100% to them
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

      // Find people who are still assigned after removal
      final remainingPeople =
          widget.assignedPeople.where((p) => p != person).toList();

      // If there are still people assigned, redistribute percentages proportionally
      if (remainingPeople.isNotEmpty) {
        double totalRemaining = 0.0;
        for (var p in remainingPeople) {
          totalRemaining += newAssignments[p] ?? 0.0;
        }

        if (totalRemaining > 0) {
          // Calculate scaling factor to ensure total remains 100%
          double scaleFactor = 100.0 / totalRemaining;

          // Rescale remaining people's percentages
          for (var p in remainingPeople) {
            newAssignments[p] = (newAssignments[p] ?? 0.0) * scaleFactor;
          }
        }
      }

      // Update assignments through callback
      widget.onAssign(widget.item, newAssignments);
      HapticFeedback.mediumImpact();
      _showSuccessToast("Removed ${person.name}");
    } else {
      // Assign 100% to this person, 0% to everyone else
      Map<Person, double> newAssignments = {};
      for (var p in widget.participants) {
        newAssignments[p] = p == person ? 100.0 : 0.0;
      }

      // Update assignments through callback
      widget.onAssign(widget.item, newAssignments);

      // Provide visual and tactile feedback
      _playHighlightAnimation();
      HapticFeedback.mediumImpact();
      _showSuccessToast("Assigned to ${person.name}");
    }
  }

  /// Activate multi-select mode for selecting multiple participants
  ///
  /// Saves current assignments for potential restoration and clears current assignments
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

      // Clear all assignments temporarily
      Map<Person, double> clearAssignments = {};
      for (var p in widget.participants) {
        clearAssignments[p] = 0.0;
      }
      widget.onAssign(widget.item, clearAssignments);
    });
    HapticFeedback.mediumImpact();
  }

  /// Exit multi-select mode without applying changes
  ///
  /// Restores original assignments if no selections were made
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

  /// Restore assignments to their state before entering multi-select mode
  void _restoreOriginalAssignments() {
    if (_savedAssignmentsBeforeMultiSelect != null) {
      // Restore the original assignments through callback
      widget.onAssign(widget.item, _savedAssignmentsBeforeMultiSelect!);
      _savedAssignmentsBeforeMultiSelect = null; // Clear the saved state
    }
  }

  /// Open custom split dialog for precise percentage assignment
  ///
  /// Shows error if no people are selected in multi-select mode
  void _showCustomSplitWithSelectedPeople() {
    if (_selectedPeople.isEmpty) {
      // Show error message if no people are selected
      if (mounted) {
        final brightness = Theme.of(context).brightness;

        // Theme-aware snackbar background
        final snackBarBgColor =
            brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade700;

        // Display floating snackbar with selection instruction
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

    // Exit multi-select mode but keep the card expanded
    setState(() {
      _multiSelectMode = false;
      _selectedPeople.clear();
    });

    // Call the callback to show the custom split dialog
    // Using the stored variables to ensure they're not accessed after state change
    onShowCustomSplit(item, selectedPeopleList);

    // Clear saved assignments since we've applied new ones
    _savedAssignmentsBeforeMultiSelect = null;
  }

  /// Split the item evenly among all participants
  ///
  /// Assigns the item equally to everyone in the participants list
  void _splitEvenlyAll() {
    widget.onSplitEvenly(widget.item, widget.participants);
    _playHighlightAnimation();
    _showSuccessToast('Split evenly among all');
  }

  /// Display a success toast message at the top of the screen
  ///
  /// Shows a temporary notification with the specified message
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

    // First hide any current SnackBar
    scaffold.hideCurrentSnackBar();

    // Get the top padding value to account for status bar height
    final topPadding = MediaQuery.of(context).padding.top;

    scaffold.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () {
            scaffold.hideCurrentSnackBar();
          },
          child: Row(
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
        ),
        backgroundColor: successToastColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Position the toast about 1/6 of the way down from the top of the screen
        margin: EdgeInsets.only(
          top: topPadding + 60, // Move it down further from the top
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).size.height - 150 - topPadding,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Calculate a dominant color with enhanced visibility for dark mode
  ///
  /// Applies special handling for purple hues which are difficult to see in dark mode
  Color getDominantColorForTheme(
    List<Person> assignedPeople,
    Brightness brightness,
  ) {
    // Get base color from assigned people
    Color baseColor = ColorUtils.getDominantColor(assignedPeople);

    // For dark mode, lighten colors for better visibility
    if (brightness == Brightness.dark) {
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
    // Get theme info for adaptive styling
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Calculate theme-aware color variables
    // These adapt all UI elements to current theme brightness
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
                ? ColorUtils.getDarkenedColor(dominantColor, 0.5).withValues(
                  alpha: 0.4,
                ) // Less darkening, more opacity
                : colorScheme.surfaceContainerHighest)
            : (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.92)
                : Colors.white);

    // Border color for card - more visible in dark mode
    final containerBorderColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? dominantColor.withValues(
                  alpha: 0.6,
                ) // Increase opacity for better visibility
                : colorScheme.outline.withValues(alpha: .3))
            : (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.7)
                : Colors.grey.shade200);

    // Shadow color - subtler in light mode, more pronounced in dark
    final shadowColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? dominantColor.withValues(alpha: .2)
                : Colors.black.withValues(alpha: .1))
            : (isAssigned
                ? dominantColor.withValues(alpha: .1)
                : Colors.black.withValues(alpha: .03));

    // Highlight shadow color - enhanced for dark mode
    final highlightShadowColor =
        brightness == Brightness.dark
            ? dominantColor.withValues(
              alpha: .7,
            ) // Stronger highlight in dark mode
            : dominantColor.withValues(alpha: .3);

    // Icon background color - brighter in dark mode for visibility
    final iconBgColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? ColorUtils.getLightenedColor(dominantColor, 0.2).withValues(
                  alpha: 0.4,
                ) // Much brighter for contrast
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
                ) // Much brighter text for contrast
                : colorScheme.onSurface)
            : (isAssigned ? dominantColor : themeSlateGray);

    final priceColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? ColorUtils.getLightenedColor(
                  dominantColor,
                  0.2,
                ).withValues(alpha: .9)
                : colorScheme.onSurface.withValues(alpha: .7))
            : (isAssigned
                ? dominantColor.withValues(alpha: .8)
                : themeLightSlateGray);

    // Divider color - more visible in dark mode
    final dividerColor =
        brightness == Brightness.dark
            ? (isAssigned
                ? dominantColor.withValues(
                  alpha: 0.3,
                ) // Brighter divider in dark mode
                : colorScheme.outline.withValues(alpha: .2))
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
          // Card header - always visible part with item details
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            splashColor: dominantColor.withValues(alpha: .05),
            highlightColor: dominantColor.withValues(alpha: .1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Item icon with assignment status indicator
                  Stack(
                    children: [
                      // Icon background - adapts to assignment state
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
                                      color: dominantColor.withValues(
                                        alpha: .3,
                                      ),
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

                      // Green checkmark dot for fully assigned items
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

                  // Assignment status section at right side
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status text badge (Unassigned/Assigned/Percentage)
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

                      // Either show assignee avatars or expand indicator
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

          // Expandable section with participant selector and action buttons
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Divider between header and expanded content
                  Container(
                    height: 1,
                    color: dividerColor,
                    margin: const EdgeInsets.only(bottom: 6),
                  ),

                  // Participant selector with action buttons - tighter padding
                  Column(
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
                        assignments: widget.item.assignments,
                      ),

                      // Action buttons with adjusted spacing and padding
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _buildActionButtons(dominantColor, brightness),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a status tag indicating assignment state (unassigned/partial/full)
  ///
  /// Shows color-coded pills with status text based on assignment percentage
  Widget _buildAssignmentStatus(
    bool isAssigned,
    bool isFullyAssigned,
    Color dominantColor,
    Color themePrimaryBlue,
    Color themeSuccessGreen,
    Color themeWarningOrange,
    Brightness brightness,
  ) {
    // Theme-aware background colors for status tags
    final unassignedBgColor =
        brightness == Brightness.dark
            ? themeWarningOrange.withValues(alpha: .2)
            : themeWarningOrange.withValues(alpha: .15);

    final fullyAssignedBgColor =
        brightness == Brightness.dark
            ? themeSuccessGreen.withValues(alpha: .2)
            : themeSuccessGreen.withValues(alpha: .15);

    final partiallyAssignedBgColor =
        brightness == Brightness.dark
            ? themePrimaryBlue.withValues(alpha: .2)
            : themePrimaryBlue.withValues(alpha: .15);

    if (!isAssigned) {
      // Unassigned status tag (orange)
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
      // Fully assigned status tag (green)
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
      // Partially assigned status tag (blue with percentage)
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

  /// Build the avatar stack showing assigned people
  ///
  /// Shows circular avatars with initials, overlapping slightly
  /// Limits display to 3 avatars plus a +N indicator for more
  Widget _buildAssigneeAvatars() {
    if (widget.assignedPeople.isEmpty) return const SizedBox.shrink();

    // Limit to showing max 3 avatars to avoid overcrowding
    final displayPeople =
        widget.assignedPeople.length > 3
            ? widget.assignedPeople.sublist(0, 3)
            : widget.assignedPeople;

    // Calculate a fixed width for the container based on number of avatars
    // Add extra padding to ensure borders aren't cut off in dark mode
    final containerWidth =
        widget.assignedPeople.length > 3
            ? 4 * 12.0 +
                16.0 // 4 avatars at 12px spacing plus buffer for borders
            : displayPeople.length * 12.0 + 16.0;

    // Theme-aware colors for avatar styling
    final brightness = Theme.of(context).brightness;
    final borderColor =
        brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.white;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .2)
            : Colors.black.withValues(alpha: .1);

    final moreAvatarBgColor =
        brightness == Brightness.dark
            ? const Color(0xFF7F9DBA) // Lighter slate in dark mode
            : const Color(0xFF627D98);

    return SizedBox(
      height: 24,
      width: containerWidth, // Fixed width based on number of avatars
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Generate overlapping avatars for each person to display
          for (int i = 0; i < displayPeople.length; i++)
            Positioned(
              // Add extra padding on right to ensure borders don't get cut off
              right: i * 12.0 + 3.0,
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

          // If there are more than 3 people, show +N indicator
          if (widget.assignedPeople.length > 3)
            Positioned(
              // Add extra padding on right to ensure borders don't get cut off
              right: 3 * 12.0 + 3.0,
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

  /// Build action buttons for the expanded section
  ///
  /// Shows different buttons based on the current state:
  /// - Split Evenly: Always visible
  /// - Multi-Split/Split It!: Context-dependent based on mode
  /// - Done/Cancel: For closing the expanded view
  Widget _buildActionButtons(Color dominantColor, Brightness brightness) {
    // Theme-aware gradient colors for buttons
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

    final disabledGradient =
        brightness == Brightness.dark
            ? [
              Colors.grey.shade700, // Lighter gray for dark mode
              Colors.grey.shade800,
            ]
            : [
              Colors.grey.shade300, // Lighter gray for light mode
              Colors.grey.shade400,
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

    // Theme-aware colors for the cancel/done button
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
            ? Colors.black.withValues(
              alpha: 0.9,
            ) // Dark text for better contrast in dark mode
            : Colors.white;

    // Disabled button text color
    final disabledTextColor =
        brightness == Brightness.dark
            ? Colors
                .grey
                .shade400 // Dimmed text for dark mode
            : Colors.grey.shade600; // Dimmed text for light mode

    // Check if button should be enabled in multi-select mode
    final bool isSplitItEnabled = _selectedPeople.isNotEmpty;

    return Column(
      children: [
        // Main action buttons row with two buttons side by side
        Row(
          children: [
            // Split evenly button (always present)
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
                isEnabled: true,
              ),
            ),

            const SizedBox(width: 10),

            // Multi-split/Split It! button (context dependent)
            Expanded(
              child:
                  _multiSelectMode
                      ? _buildModernButton(
                        label: 'Split It!',
                        icon: Icons.flash_on,
                        gradient: LinearGradient(
                          colors:
                              isSplitItEnabled
                                  ? greenGradient
                                  : disabledGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor:
                            isSplitItEnabled
                                ? buttonTextColor
                                : disabledTextColor,
                        onTap: _showCustomSplitWithSelectedPeople,
                        isEnabled: isSplitItEnabled,
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
                        isEnabled: true,
                      ),
            ),
          ],
        ),

        // Done/Cancel button at the bottom
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GestureDetector(
            onTap: () {
              // If in multi-select mode, cancel it
              if (_multiSelectMode) {
                _cancelMultiSelectMode();
              } else {
                // Only close when pressing "Done" (not in multi-select mode)
                setState(() {
                  _isExpanded = false;
                  _animController.reverse();
                });
              }
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

  /// Build a modern-styled gradient button with icon and label
  ///
  /// Creates an attractive button with rounded corners, gradient background,
  /// and slight elevation for a three-dimensional effect
  Widget _buildModernButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    required Color textColor,
    required bool isEnabled,
  }) {
    return GestureDetector(
      onTap: () {
        if (isEnabled) {
          onTap();
          HapticFeedback.mediumImpact();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .1),
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
