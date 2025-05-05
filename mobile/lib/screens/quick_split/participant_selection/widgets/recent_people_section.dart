import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';

/// Displays recently used people as interactive chips that can be quickly selected
/// Uses a responsive wrap layout to handle variable-width names gracefully
class RecentPeopleSection extends StatelessWidget {
  final List<Person> recentPeople;

  const RecentPeopleSection({super.key, required this.recentPeople});

  @override
  Widget build(BuildContext context) {
    if (recentPeople.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);
    final labelColor = colorScheme.onSurface.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(labelColor, textTheme, colorScheme),
        const SizedBox(height: 10),
        _buildChipsWrap(recentPeople, participantsProvider),
      ],
    );
  }

  /// Creates the section header with icon and title
  Widget _buildSectionHeader(
    Color labelColor,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Row(
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
    );
  }

  /// Builds a flowing wrap of person chips
  Widget _buildChipsWrap(List<Person> people, ParticipantsProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          people.map((person) {
            return _RecentPersonChip(
              person: person,
              isSelected: provider.isPersonSelected(person),
              onTap: () => provider.toggleRecentPerson(person),
            );
          }).toList(),
    );
  }
}

/// Interactive chip that toggles selection state with animated visual feedback
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pre-calculate theme-adaptive colors
    final unselectedBgColor =
        isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50;

    final unselectedBorderColor =
        isDark
            ? colorScheme.outline.withValues(alpha: 0.2)
            : Colors.grey.shade300;

    final unselectedTextColor =
        isDark
            ? colorScheme.onSurface.withValues(alpha: 0.7)
            : Colors.grey.shade700;

    // Dynamic color calculation based on theme
    final selectedTextColor =
        isDark
            ? ColorUtils.getLightenedColor(person.color, 0.8)
            : ColorUtils.getDarkenedColor(person.color, 0.3);

    final selectedBgOpacity = isDark ? 0.25 : 0.12;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: _buildChipDecoration(
          isDark: isDark,
          isSelected: isSelected,
          unselectedBgColor: unselectedBgColor,
          unselectedBorderColor: unselectedBorderColor,
          selectedBgOpacity: selectedBgOpacity,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSelectionIndicator(isDark),
            _buildChipText(
              isDark: isDark,
              isSelected: isSelected,
              selectedTextColor: selectedTextColor,
              unselectedTextColor: unselectedTextColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Creates the container decoration based on selection state
  BoxDecoration _buildChipDecoration({
    required bool isDark,
    required bool isSelected,
    required Color unselectedBgColor,
    required Color unselectedBorderColor,
    required double selectedBgOpacity,
  }) {
    return BoxDecoration(
      color:
          isSelected
              ? person.color.withValues(alpha: selectedBgOpacity)
              : unselectedBgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isSelected ? person.color : unselectedBorderColor,
        width: isSelected ? 1.5 : 1,
      ),
      boxShadow:
          isSelected && isDark
              ? [
                BoxShadow(
                  color: person.color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ]
              : null,
    );
  }

  /// Creates the animated selection indicator dot
  Widget _buildSelectionIndicator(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: isSelected ? 8 : 0,
      height: isSelected ? 8 : 0,
      margin: EdgeInsets.only(right: isSelected ? 6 : 0),
      decoration: BoxDecoration(
        color:
            isDark
                ? ColorUtils.getLightenedColor(person.color, 0.3)
                : person.color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Creates the animated text with style changes on selection
  Widget _buildChipText({
    required bool isDark,
    required bool isSelected,
    required Color selectedTextColor,
    required Color unselectedTextColor,
  }) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      style: TextStyle(
        color: isSelected ? selectedTextColor : unselectedTextColor,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
        shadows:
            isSelected && isDark
                ? [
                  const Shadow(
                    color: Colors.black,
                    offset: Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
                : null,
      ),
      child: Text(person.name),
    );
  }
}
