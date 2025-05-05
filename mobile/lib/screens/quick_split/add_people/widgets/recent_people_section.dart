import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';
import '../providers/participants_provider.dart';

/// Displays a section showing recently used people that can be quickly selected
/// Uses a wrap layout to handle variable width names in a responsive way
class RecentPeopleSection extends StatelessWidget {
  final List<Person> recentPeople;

  const RecentPeopleSection({super.key, required this.recentPeople});

  @override
  Widget build(BuildContext context) {
    // Skip rendering if there are no recent people
    if (recentPeople.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);

    // Theme-aware color for secondary UI elements
    final labelColor = colorScheme.onSurface.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with history icon
        Row(
          children: [
            Icon(Icons.history, size: 18, color: labelColor),
            const SizedBox(width: 8),
            Text(
              "Recent People",
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Wrap layout automatically handles flowing items to next line
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

/// Interactive chip displaying a person's name with selection state
/// Animates between selected/unselected states with color, weight, and dot indicator changes
class _RecentPersonChip extends StatelessWidget {
  final Person person;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecentPersonChip({
    required this.person,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Define theme-adaptive colors for different states
    final unselectedBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade50;

    final unselectedBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: 0.2)
            : Colors.grey.shade300;

    final unselectedTextColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: 0.7)
            : Colors.grey.shade700;

    // Adjust text color based on theme for better contrast
    final selectedTextColor =
        brightness == Brightness.dark
            ? ColorUtils.getLightenedColor(person.color, 0.8)
            : ColorUtils.getDarkenedColor(person.color, 0.3);

    // Use different opacity values for dark/light modes
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
                    ? person.color.withValues(alpha: selectedBgOpacity)
                    : unselectedBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? person.color : unselectedBorderColor,
              width: isSelected ? 1.5 : 1,
            ),
            // Only show shadow effect when selected in dark mode
            boxShadow:
                isSelected && brightness == Brightness.dark
                    ? [
                      BoxShadow(
                        color: person.color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection indicator dot that grows when selected
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isSelected ? 8 : 0,
                height: isSelected ? 8 : 0,
                margin: EdgeInsets.only(right: isSelected ? 6 : 0),
                decoration: BoxDecoration(
                  color:
                      brightness == Brightness.dark
                          ? ColorUtils.getLightenedColor(person.color, 0.3)
                          : person.color,
                  shape: BoxShape.circle,
                ),
              ),
              // Text with animated style changes
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                  // Add shadow in dark mode for better readability
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
