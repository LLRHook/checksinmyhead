import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BottomBar extends StatelessWidget {
  final VoidCallback onShareTap;
  final VoidCallback onDoneTap;

  const BottomBar({Key? key, required this.onShareTap, required this.onDoneTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShareTap,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onDoneTap,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Done'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class to handle the done button functionality
class DoneButtonHandler {
  static void handleDone(BuildContext context) {
    // Show success message and navigate
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    // Navigate to first screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
