import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';

/// Displays and manages the list of current participants with animated removal effects
class CurrentParticipantsSection extends StatefulWidget {
  final AnimationController animationController;

  const CurrentParticipantsSection({
    super.key,
    required this.animationController,
  });

  @override
  State<CurrentParticipantsSection> createState() =>
      _CurrentParticipantsSectionState();
}

class _CurrentParticipantsSectionState
    extends State<CurrentParticipantsSection> {
  /// Shows a confirmation dialog and clears all participants if confirmed
  void _confirmClearAll(BuildContext context, ParticipantsProvider provider) {
    HapticFeedback.mediumImpact();
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Clear all participants?"),
            content: const Text(
              "This will remove all people from your current list.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  provider.clearAll();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Clear All"),
              ),
            ],
          ),
    );
  }

  /// Animates the removal of a person before actually removing them from the list
  void _removePerson(int index, BuildContext context, Person person) {
    final provider = Provider.of<ParticipantsProvider>(context, listen: false);

    // Create fade animation and register it with the provider
    final fadeAnimation = widget.animationController.drive(
      Tween<double>(begin: 1.0, end: 0.0),
    );
    provider.registerAnimation(person.name, fadeAnimation);

    // Reset and run the animation, then remove the person when complete
    widget.animationController.reset();
    widget.animationController.forward().then((_) {
      provider.removePerson(index);
      provider.unregisterAnimation(person.name);
    });

    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);
    final participants = participantsProvider.participants;
    final labelColor = colorScheme.onSurface.withValues(alpha: 0.7);

    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          labelColor,
          textTheme,
          colorScheme,
          participantsProvider,
        ),
        const SizedBox(height: 12),
        _buildParticipantsList(participants, participantsProvider),
      ],
    );
  }

  /// Creates the section header with title and optional clear button
  Widget _buildSectionHeader(
    BuildContext context,
    Color labelColor,
    TextTheme textTheme,
    ColorScheme colorScheme,
    ParticipantsProvider participantsProvider,
  ) {
    return Row(
      children: [
        Icon(Icons.people, size: 18, color: labelColor),
        const SizedBox(width: 8),
        Text(
          "Current Participants",
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        if (participantsProvider.participants.length > 1)
          TextButton.icon(
            onPressed: () => _confirmClearAll(context, participantsProvider),
            icon: Icon(Icons.clear_all, size: 18, color: labelColor),
            label: Text(
              "Clear All",
              style: TextStyle(color: labelColor, fontSize: 12),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
      ],
    );
  }

  /// Builds the animated list of participants
  Widget _buildParticipantsList(
    List<Person> participants,
    ParticipantsProvider participantsProvider,
  ) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final person = participants[index];
        final animations = participantsProvider.listItemAnimations;
        final animation = animations[person.name];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildAnimatedListItem(person, animation, index, context),
        );
      },
    );
  }

  /// Creates an animated list item with slide, fade and size transitions
  Widget _buildAnimatedListItem(
    Person person,
    Animation<double>? animation,
    int index,
    BuildContext context,
  ) {
    return SlideTransition(
      position:
          animation != null
              ? Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(1.5, 0), // Slide right off screen
              ).animate(
                CurvedAnimation(
                  parent: widget.animationController,
                  curve: Curves.easeOutCubic,
                ),
              )
              : const AlwaysStoppedAnimation<Offset>(Offset.zero),
      child: FadeTransition(
        opacity: animation ?? const AlwaysStoppedAnimation<double>(1.0),
        child: SizeTransition(
          sizeFactor: animation ?? const AlwaysStoppedAnimation<double>(1.0),
          axisAlignment: 0.0,
          child: _ParticipantListItem(
            person: person,
            onRemove: () => _removePerson(index, context, person),
          ),
        ),
      ),
    );
  }
}

/// A themed list item for participants with color-coding and removal option
class _ParticipantListItem extends StatelessWidget {
  final Person person;
  final VoidCallback onRemove;

  const _ParticipantListItem({required this.person, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Apply theme-aware styling
    final backgroundOpacity = isDark ? 0.15 : 0.08;
    final borderOpacity = isDark ? 0.3 : 0.2;
    final backgroundColor = person.color.withValues(alpha: backgroundOpacity);

    // Calculate dynamic text color based on theme and person color
    final textColor =
        isDark
            ? ColorUtils.getLightenedColor(
              person.color,
              0.7,
            ) // Lighten in dark mode
            : ColorUtils.getDarkenedColor(
              person.color,
              0.3,
            ); // Darken in light mode

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: person.color.withValues(alpha: borderOpacity),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: person.color,
          child: Text(
            person.name[0].toUpperCase(),
            style: TextStyle(
              color: ColorUtils.getContrastiveTextColor(person.color),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          person.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
            // Add shadow in dark mode for better visibility
            shadows:
                isDark
                    ? [
                      const Shadow(
                        color: Colors.black,
                        offset: Offset(0, 1),
                        blurRadius: 1,
                      ),
                    ]
                    : null,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          onPressed: onRemove,
          tooltip: "Remove ${person.name}",
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
