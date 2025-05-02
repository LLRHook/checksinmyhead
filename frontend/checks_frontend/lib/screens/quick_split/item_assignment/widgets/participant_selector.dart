import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/screens/quick_split/item_assignment/widgets/participant_avatar.dart';

/// A simplified and reusable participant selector component
class ParticipantSelector extends StatelessWidget {
  final List<Person> participants;
  final List<Person> assignedPeople;
  final Set<Person> selectedPeople; // Controlled by parent
  final Person? birthdayPerson;
  final Function(Person) onPersonTap;
  final Function(Person) onBirthdayToggle;
  final bool isMultiSelectMode; // Controlled by parent

  const ParticipantSelector({
    Key? key,
    required this.participants,
    required this.assignedPeople,
    required this.selectedPeople,
    required this.birthdayPerson,
    required this.onPersonTap,
    required this.onBirthdayToggle,
    this.isMultiSelectMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Ensure the column takes minimum space
      children: [
        // Multi-select header - with a fixed height
        if (isMultiSelectMode)
          SizedBox(
            height: 40, // Fixed height for the header
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  // Use Flexible to prevent overflow
                  Flexible(
                    child: Text(
                      'Select people to split with',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF3B82F6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedPeople.isEmpty
                        ? ''
                        : selectedPeople.length.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Reduced vertical spacing
        const SizedBox(height: 6),

        // Participants scrollable list with fixed height
        SizedBox(
          height: 70, // Fixed height for the avatars list
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: participants.length,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              final person = participants[index];
              final isAssigned = assignedPeople.contains(person);
              final isSelected = selectedPeople.contains(person);
              final isBirthdayPerson = birthdayPerson == person;

              return ParticipantAvatar(
                person: person,
                isAssigned:
                    isMultiSelectMode
                        ? false
                        : isAssigned, // Hide assignment indicators in multi-select mode
                isSelected: isSelected,
                isBirthdayPerson: isBirthdayPerson,
                onTap: () => onPersonTap(person),
                onLongPress: () => onBirthdayToggle(person),
              );
            },
          ),
        ),
      ],
    );
  }
}
