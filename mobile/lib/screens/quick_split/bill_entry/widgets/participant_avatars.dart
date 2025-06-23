// Spliq: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:checks_frontend/screens/quick_split/item_assignment/utils/color_utils.dart';
import 'package:flutter/material.dart';
import '/models/person.dart';

/// ParticipantAvatars - Horizontal scrollable display of bill participants
///
/// Displays a row of circular avatars with names representing the people
/// participating in the bill split. Each avatar uses the person's assigned color
/// and first letter of their name.
///
/// Features:
/// - Horizontally scrollable container for any number of participants
/// - Color-coded avatars with shadow effects for depth
/// - Automatically handles name truncation for longer names
/// - Adapts colors for both light and dark themes
/// - Uses contrast calculations to ensure text readability on colored backgrounds
///
/// Inputs:
///   - participants: List of Person objects to display
class ParticipantAvatars extends StatelessWidget {
  final List<Person> participants;

  const ParticipantAvatars({super.key, required this.participants});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Container background adapts to theme - more opaque in dark mode
    final containerColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.withValues(alpha: .3);

    // Name text color - solid in dark mode, variant in light mode
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
                // Avatar with shadow for depth
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: person.color.withValues(alpha: .3),
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
                        // Using ColorUtils to ensure readable text on any background color
                        color: ColorUtils.getContrastiveTextColor(person.color),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Fixed width container for name with ellipsis for overflow
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
