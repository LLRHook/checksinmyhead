import 'package:flutter/material.dart';
import '/models/person.dart';
import '/screens/quick_split/item_assignment/widgets/participant_avatar.dart';

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

  const ParticipantSelector({
    super.key,
    required this.participants,
    required this.assignedPeople,
    required this.selectedPeople,
    required this.birthdayPerson,
    required this.onPersonTap,
    required this.onBirthdayToggle,
    this.isMultiSelectMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-aware colors for better readability in both light and dark modes
    final primaryBlueColor =
        brightness == Brightness.dark
            ? Color(0xFF60A5FA) // Lighter blue for better contrast in dark mode
            : Color(0xFF3B82F6); // Standard blue for light mode

    final headerTextColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withValues(
              alpha: .9,
            ) // Slightly transparent in dark mode
            : primaryBlueColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:
          MainAxisSize.min, // Prevent column from expanding unnecessarily
      children: [
        // Multi-select mode header - only shown when multi-select is active
        if (isMultiSelectMode)
          SizedBox(
            height:
                40, // Fixed height prevents layout shifts when toggling modes
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  // Touch icon indicates interactive selection mode
                  Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: primaryBlueColor,
                  ),
                  const SizedBox(width: 8),
                  // Flexible prevents text overflow on smaller screens
                  Flexible(
                    child: Text(
                      'Select people to split with:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: headerTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Selection counter - empty when no selections to avoid "0" display
                  Text(
                    selectedPeople.isEmpty
                        ? ''
                        : selectedPeople.length.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: headerTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Small spacing between header and avatar list
        const SizedBox(height: 6),

        // Horizontally scrollable avatar list with consistent fixed height
        SizedBox(
          height:
              70, // Fixed height ensures consistent UI across different screens
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: participants.length,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              final person = participants[index];

              // Determine participant states for visual indicators
              final isAssigned = assignedPeople.contains(person);
              final isSelected = selectedPeople.contains(person);
              final isBirthdayPerson = birthdayPerson == person;

              // In multi-select mode, we hide assignment indicators to avoid visual confusion
              final showAssignedIndicator =
                  isMultiSelectMode ? false : isAssigned;

              return ParticipantAvatar(
                person: person,
                isAssigned: showAssignedIndicator,
                isSelected: isSelected,
                isBirthdayPerson: isBirthdayPerson,
                onTap: () => onPersonTap(person),
                onLongPress:
                    () => onBirthdayToggle(
                      person,
                    ), // Long press toggles birthday status
              );
            },
          ),
        ),
      ],
    );
  }
}
