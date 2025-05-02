import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';
import '../providers/participants_provider.dart';

class CurrentParticipantsSection extends StatefulWidget {
  final AnimationController animationController;

  const CurrentParticipantsSection({
    Key? key,
    required this.animationController,
  }) : super(key: key);

  @override
  State<CurrentParticipantsSection> createState() =>
      _CurrentParticipantsSectionState();
}

class _CurrentParticipantsSectionState
    extends State<CurrentParticipantsSection> {
  void _confirmClearAll(BuildContext context, ParticipantsProvider provider) {
    // Vibrate for feedback
    HapticFeedback.mediumImpact();

    final colorScheme = Theme.of(context).colorScheme;

    // Clear all participants with confirmation
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
                    color: colorScheme.onSurface.withOpacity(0.7),
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

  void _removePerson(int index, BuildContext context, Person person) {
    final provider = Provider.of<ParticipantsProvider>(context, listen: false);

    // Create the opacity animation
    final fadeAnimation = widget.animationController.drive(
      Tween<double>(begin: 1.0, end: 0.0),
    );

    // Register the animation with the provider
    provider.registerAnimation(person.name, fadeAnimation);

    // Reset the animation controller
    widget.animationController.reset();

    // Run the animation
    widget.animationController.forward().then((_) {
      // Once animation completes, actually remove the person
      provider.removePerson(index);
      provider.unregisterAnimation(person.name);
    });

    // Vibrate to confirm removal
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);
    final participants = participantsProvider.participants;

    // Theme-aware colors
    final labelColor = colorScheme.onSurface.withOpacity(0.7);

    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, size: 18, color: labelColor),
            const SizedBox(width: 8),
            Text(
              "Current Participants",
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface, // Use theme-aware color
              ),
            ),
            const Spacer(),
            if (participants.length > 1)
              TextButton.icon(
                onPressed:
                    () => _confirmClearAll(context, participantsProvider),
                icon: Icon(Icons.clear_all, size: 18, color: labelColor),
                label: Text(
                  "Clear All",
                  style: TextStyle(color: labelColor, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Animated list items
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final person = participants[index];
            final animations = participantsProvider.listItemAnimations;
            final animation = animations[person.name];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SlideTransition(
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
                  opacity:
                      animation ?? const AlwaysStoppedAnimation<double>(1.0),
                  child: SizeTransition(
                    sizeFactor:
                        animation ?? const AlwaysStoppedAnimation<double>(1.0),
                    axisAlignment: 0.0,
                    child: _ParticipantListItem(
                      person: person,
                      onRemove: () => _removePerson(index, context, person),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ParticipantListItem extends StatelessWidget {
  final Person person;
  final VoidCallback onRemove;

  const _ParticipantListItem({
    Key? key,
    required this.person,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Adjust opacity based on theme brightness
    final backgroundOpacity = brightness == Brightness.dark ? 0.15 : 0.08;
    final borderOpacity = brightness == Brightness.dark ? 0.3 : 0.2;

    // Get the proper text color based on background color and theme
    // We'll lighten the color in dark mode or darken it in light mode for better contrast
    final backgroundColor = person.color.withOpacity(backgroundOpacity);

    // Use ColorUtils to determine the best text color
    // For dark mode, use a much lighter version of the person's color
    final textColor =
        brightness == Brightness.dark
            ? ColorUtils.getLightenedColor(
              person.color,
              0.7,
            ) // Lighten by 70% for dark mode
            : ColorUtils.getDarkenedColor(
              person.color,
              0.3,
            ); // Darken by 30% for light mode

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: person.color.withOpacity(borderOpacity),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: person.color,
          child: Text(
            person.name[0].toUpperCase(),
            // Use ColorUtils to determine the best text color for the avatar
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
            // Add a subtle text shadow in dark mode for better visibility
            shadows:
                brightness == Brightness.dark
                    ? [
                      Shadow(
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
