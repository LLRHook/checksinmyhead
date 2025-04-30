import 'package:checks_frontend/screens/quick_split/bill_summary/utils/color_utils.dart';
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
                  style: TextStyle(color: Colors.grey.shade700),
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

    // Create a sliding animation for this specific person
    final slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0), // Slide right and off-screen
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeOutCubic,
      ),
    );

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
    final participantsProvider = Provider.of<ParticipantsProvider>(context);
    final participants = participantsProvider.participants;

    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              "Current Participants",
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            if (participants.length > 1)
              TextButton.icon(
                onPressed:
                    () => _confirmClearAll(context, participantsProvider),
                icon: Icon(
                  Icons.clear_all,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
                label: Text(
                  "Clear All",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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

            // Get darker shade for text
            final textColor = ColorUtils.getDarkenedColor(person.color, 0.3);

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
                      textColor: textColor,
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
  final Color textColor;
  final VoidCallback onRemove;

  const _ParticipantListItem({
    Key? key,
    required this.person,
    required this.textColor,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: person.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: person.color.withOpacity(0.2), width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: person.color,
          child: Text(
            person.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          person.name,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
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
