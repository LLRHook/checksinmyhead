import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);

    // Use theme-aware colors for the icon and text
    final labelColor = colorScheme.onSurface.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: labelColor),
            const SizedBox(width: 8),
            Text(
              "Recent People",
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    colorScheme
                        .onSurface, // Use theme's onSurface instead of hardcoded color
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
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware background colors
    final unselectedBgColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade50;

    final unselectedBorderColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.2)
            : Colors.grey.shade300;

    final unselectedTextColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.onSurface.withOpacity(0.7)
            : Colors.grey.shade700;

    // Determine the best text color for selected state
    Color selectedTextColor;
    if (brightness == Brightness.dark) {
      // For dark mode, use a much lighter version of the color for better visibility
      selectedTextColor = ColorUtils.getLightenedColor(person.color, 0.8);
    } else {
      // For light mode, use a darker version
      selectedTextColor = ColorUtils.getDarkenedColor(person.color, 0.3);
    }

    // For selected background in dark mode, use a lighter opacity
    final selectedBgOpacity = brightness == Brightness.dark ? 0.25 : 0.12;

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
                    ? person.color.withOpacity(selectedBgOpacity)
                    : unselectedBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? person.color : unselectedBorderColor,
              width: isSelected ? 1.5 : 1,
            ),
            // Add subtle shadow for selected items in dark mode
            boxShadow:
                isSelected && brightness == Brightness.dark
                    ? [
                      BoxShadow(
                        color: person.color.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ]
                    : null,
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
                  color:
                      brightness == Brightness.dark
                          ? ColorUtils.getLightenedColor(
                            person.color,
                            0.3,
                          ) // Brighter dot for dark mode
                          : person.color,
                  shape: BoxShape.circle,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                  // Add text shadow for better visibility in dark mode
                  shadows:
                      isSelected && brightness == Brightness.dark
                          ? [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ]
                          : null,
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
