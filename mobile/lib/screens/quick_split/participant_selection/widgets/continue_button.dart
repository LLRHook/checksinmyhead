// Billington: Privacy-first receipt spliting
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

import 'package:checks_frontend/screens/quick_split/participant_selection/providers/participants_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A context-aware button that enables/disables based on participant selection,
/// showing a count badge when participants are present.
class ContinueButton extends StatelessWidget {
  final VoidCallback onContinue;

  const ContinueButton({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);
    final hasParticipants = participantsProvider.hasParticipants;
    final participantsCount = participantsProvider.participants.length;

    // Pre-calculate theme-dependent colors
    final disabledBgColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.surface.withValues(alpha: 0.2)
            : Colors.grey.shade200;
    final disabledTextColor =
        colorScheme.brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: 0.4)
            : Colors.grey.shade500;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Semantics(
        label: hasParticipants
            ? 'Continue with $participantsCount ${participantsCount == 1 ? 'person' : 'people'}'
            : 'Continue, disabled, add participants first',
        button: true,
        enabled: hasParticipants,
        child: ElevatedButton(
        onPressed: hasParticipants ? onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasParticipants ? colorScheme.primary : disabledBgColor,
          foregroundColor:
              hasParticipants ? colorScheme.onPrimary : disabledTextColor,
          elevation: hasParticipants ? 2 : 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: colorScheme.primary.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Continue",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    hasParticipants ? colorScheme.onPrimary : disabledTextColor,
              ),
            ),
            if (hasParticipants) ...[
              const SizedBox(width: 8),
              ExcludeSemantics(child: _buildCountBadge(participantsCount, colorScheme)),
            ],
          ],
        ),
      ),
      ),
    );
  }

  /// Creates a pill-shaped badge showing participant count with proper pluralization
  Widget _buildCountBadge(int count, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "$count ${count == 1 ? 'person' : 'people'}",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
