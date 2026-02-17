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

import 'package:flutter/material.dart';
import 'package:checks_frontend/models/person.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/widgets/participant_avatar.dart';

/// ParticipantSelector
///
/// A reusable widget that displays a horizontal list of participant avatars with
/// selection, assignment, and birthday person functionality.
///
/// This component allows users to:
/// 1. Select individual or multiple participants
/// 2. Toggle birthday status for special pricing calculations
/// 3. View assignment status in non-multi-select mode
///
/// The component adapts its appearance based on the current theme (light/dark mode)
/// and maintains a consistent height to prevent layout jumps.
///
/// Inputs:
/// - participants: List of all available people to display
/// - assignedPeople: People who are currently assigned to an item
/// - selectedPeople: Currently selected people (controlled by parent)
/// - birthdayPerson: Person marked as having a birthday (for special calculations)
/// - onPersonTap: Callback when a person avatar is tapped
/// - onBirthdayToggle: Callback when long-pressing to toggle birthday status
/// - isMultiSelectMode: Whether multiple selection is enabled
///
/// Side effects: None - this is a stateless UI component that triggers
/// callbacks provided by the parent widget
class ParticipantSelector extends StatelessWidget {
  final List<Person> participants;
  final List<Person> assignedPeople;
  final Set<Person> selectedPeople; // Controlled by parent
  final Person? birthdayPerson;
  final Function(Person) onPersonTap;
  final Function(Person) onBirthdayToggle;
  final bool isMultiSelectMode; // Controlled by parent
  final Map<Person, double>? assignments; // Optional assignment percentages

  const ParticipantSelector({
    super.key,
    required this.participants,
    required this.assignedPeople,
    required this.selectedPeople,
    required this.birthdayPerson,
    required this.onPersonTap,
    required this.onBirthdayToggle,
    this.isMultiSelectMode = false,
    this.assignments,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Premium color scheme
    final primaryBlueColor =
        brightness == Brightness.dark
            ? const Color(0xFF60A5FA)
            : const Color(0xFF3B82F6);

    final subtleTextColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: 0.7)
            : colorScheme.onSurface.withValues(alpha: 0.6);

    // Fixed height container to prevent layout shifts
    return SizedBox(
      height: 132, // Further reduced for tighter, premium layout
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header area with fixed height - always present, content conditionally shown
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 32, // Reduced height
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              child:
                  isMultiSelectMode
                      ? Row(
                        key: const ValueKey('multiselect-header'),
                        children: [
                          // Animated icon
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Icon(
                                  Icons.touch_app_rounded,
                                  size: 18,
                                  color: primaryBlueColor,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Select people to split with:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: subtleTextColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          // Animated counter badge
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            transitionBuilder: (
                              Widget child,
                              Animation<double> animation,
                            ) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child:
                                selectedPeople.isNotEmpty
                                    ? Container(
                                      key: ValueKey(selectedPeople.length),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        selectedPeople.length.toString(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: primaryBlueColor,
                                        ),
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          ),
                        ],
                      )
                      : const SizedBox.shrink(),
            ),
          ),

          const SizedBox(height: 2), // Minimal spacing for premium feel
          // Avatar list with consistent height and premium padding
          Container(
            height: 96, // Slightly reduced height
            padding: const EdgeInsets.only(
              top: 2,
            ), // Small top padding to bring avatars slightly up
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: participants.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final person = participants[index];
                final isAssigned = assignedPeople.contains(person);
                final isSelected = selectedPeople.contains(person);
                final isBirthdayPerson = birthdayPerson == person;
                final showAssignedIndicator =
                    isMultiSelectMode ? false : isAssigned;
                final percentage = assignments?[person];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: isSelected ? 0.95 : 1.0,
                    child: ParticipantAvatar(
                      person: person,
                      isAssigned: showAssignedIndicator,
                      isSelected: isSelected,
                      isBirthdayPerson: isBirthdayPerson,
                      onTap: () => onPersonTap(person),
                      onLongPress: participants.length > 1
                          ? () => onBirthdayToggle(person)
                          : null,
                      assignedPercentage: percentage,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
