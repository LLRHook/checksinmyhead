import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import '/models/person.dart';

class ParticipantAvatars extends StatelessWidget {
  final List<Person> participants;

  const ParticipantAvatars({Key? key, required this.participants})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware container color
    final containerColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceVariant.withOpacity(0.3);

    // Theme-aware text color
    final nameColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final person = participants[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: person.color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: person.color,
                    radius: 18,
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: TextStyle(
                        // Using ColorUtils for better contrast
                        color: ColorUtils.getContrastiveTextColor(person.color),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 45,
                  child: Text(
                    person.name,
                    style: textTheme.labelSmall?.copyWith(color: nameColor),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
