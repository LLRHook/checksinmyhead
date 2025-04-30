import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/participants_provider.dart';

class ContinueButton extends StatelessWidget {
  final VoidCallback onContinue;

  const ContinueButton({Key? key, required this.onContinue}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final participantsProvider = Provider.of<ParticipantsProvider>(context);
    final hasParticipants = participantsProvider.hasParticipants;
    final participantsCount = participantsProvider.participants.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: hasParticipants ? onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasParticipants ? colorScheme.primary : Colors.grey.shade200,
          foregroundColor:
              hasParticipants ? Colors.white : Colors.grey.shade500,
          elevation: hasParticipants ? 2 : 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: colorScheme.primary.withOpacity(0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Continue",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: hasParticipants ? Colors.white : Colors.grey.shade600,
              ),
            ),
            if (hasParticipants) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$participantsCount ${participantsCount == 1 ? 'person' : 'people'}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
