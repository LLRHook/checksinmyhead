import 'package:checks_frontend/screens/quick_split/bill_summary/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';
import '../providers/participants_provider.dart';

class RecentPeopleSection extends StatelessWidget {
  final List<Person> recentPeople;

  const RecentPeopleSection({Key? key, required this.recentPeople})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (recentPeople.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              "Recent People",
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              recentPeople.map((person) {
                return _RecentPersonChip(
                  person: person,
                  isSelected: participantsProvider.isPersonSelected(person),
                  onTap: () => participantsProvider.toggleRecentPerson(person),
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _RecentPersonChip extends StatelessWidget {
  final Person person;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecentPersonChip({
    Key? key,
    required this.person,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get darker shades for better contrast
    final darkColor = ColorUtils.getDarkenedColor(person.color, 0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? person.color.withOpacity(0.12)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? person.color : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isSelected ? 8 : 0,
                height: isSelected ? 8 : 0,
                margin: EdgeInsets.only(right: isSelected ? 6 : 0),
                decoration: BoxDecoration(
                  color: person.color,
                  shape: BoxShape.circle,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isSelected ? darkColor : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
                child: Text(person.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
