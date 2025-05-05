import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/participants_provider.dart';

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
      padding: const EdgeInsets.only(bottom: 12),
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
              _buildCountBadge(participantsCount, colorScheme),
            ],
          ],
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
