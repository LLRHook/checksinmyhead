import 'package:checks_frontend/models/person.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ParticipantSelector extends StatelessWidget {
  final List<Person> participants;
  final Person? selectedPerson;
  final Person? birthdayPerson;
  final Map<Person, double> personFinalShares;
  final Function(Person) onPersonSelected;
  final Function(Person) onBirthdayToggle;
  final Function(Person) getPersonBillPercentage;

  const ParticipantSelector({
    Key? key,
    required this.participants,
    required this.selectedPerson,
    required this.birthdayPerson,
    required this.personFinalShares,
    required this.onPersonSelected,
    required this.onBirthdayToggle,
    required this.getPersonBillPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Who\'s paying for what?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          // Participant avatars with progress indicators
          _buildParticipantsList(context),

          // Birthday message
          if (birthdayPerson != null) _buildBirthdayMessage(),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 110),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final person = participants[index];
          final isSelected = selectedPerson == person;
          final isBirthdayPerson = birthdayPerson == person;
          final billPercentage = getPersonBillPercentage(person);

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => onPersonSelected(person),
              onLongPress: () => onBirthdayToggle(person),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar with progress indicator
                  _buildAvatar(
                    context,
                    person,
                    isSelected,
                    isBirthdayPerson,
                    billPercentage,
                  ),

                  const SizedBox(height: 6),

                  // Person name
                  Text(
                    person.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected || isBirthdayPerson
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),

                  // Person's share
                  _buildShareAmount(person, isBirthdayPerson, billPercentage),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    Person person,
    bool isSelected,
    bool isBirthdayPerson,
    double billPercentage,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Progress ring
        SizedBox(
          width: 65,
          height: 65,
          child: CircularProgressIndicator(
            value: billPercentage,
            strokeWidth: 3,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              isBirthdayPerson ? Colors.pink : person.color.withOpacity(0.8),
            ),
          ),
        ),

        // Person avatar
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isSelected ? 55 : 50,
          height: isSelected ? 55 : 50,
          decoration: BoxDecoration(
            color: isBirthdayPerson ? Colors.pink : person.color,
            shape: BoxShape.circle,
            boxShadow:
                isSelected || isBirthdayPerson
                    ? [
                      BoxShadow(
                        color:
                            isBirthdayPerson
                                ? Colors.pink.withOpacity(0.4)
                                : person.color.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child: Center(
            child:
                isBirthdayPerson
                    ? const Icon(Icons.cake, color: Colors.white, size: 24)
                    : Text(
                      person.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isSelected ? 24 : 20,
                      ),
                    ),
          ),
        ),

        // Selected indicator
        if (isSelected)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.check_circle,
                color: colorScheme.primary,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShareAmount(
    Person person,
    bool isBirthdayPerson,
    double billPercentage,
  ) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        fontSize: 12,
        color:
            isBirthdayPerson
                ? Colors.green
                : billPercentage > 0
                ? person.color
                : Colors.grey[600],
        fontWeight: billPercentage > 0 ? FontWeight.bold : FontWeight.normal,
      ),
      child: Text('\$${(personFinalShares[person] ?? 0).toStringAsFixed(2)}'),
    );
  }

  Widget _buildBirthdayMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.cake, size: 16, color: Colors.pink),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Their share will be evenly split amongst the others!',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
