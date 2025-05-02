import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UnassignedAmountBanner extends StatelessWidget {
  final double unassignedAmount;
  final VoidCallback onSplitEvenly;

  const UnassignedAmountBanner({
    super.key,
    required this.unassignedAmount,
    required this.onSplitEvenly,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final backgroundColor =
        brightness == Brightness.dark
            ? Color(0xFF442700).withOpacity(
              0.4,
            ) // Dark orange background for dark mode
            : Colors.orange.shade50;

    final borderColor =
        brightness == Brightness.dark
            ? Colors.orange.shade700.withOpacity(0.4)
            : Colors.orange.shade200;

    final iconColor =
        brightness == Brightness.dark
            ? Colors.orange.shade300
            : Colors.orange.shade700;

    final titleColor =
        brightness == Brightness.dark
            ? Colors.orange.shade200
            : Colors.orange.shade900;

    final subtitleColor =
        brightness == Brightness.dark
            ? Colors.orange.shade300.withOpacity(0.7)
            : Colors.orange.shade800;

    // Ensure we're using a proper GestureDetector instead of just InkWell
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onSplitEvenly();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Warning icon
              Icon(Icons.warning_amber_rounded, color: iconColor, size: 24),
              const SizedBox(width: 12),

              // Warning text with proper string interpolation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "\$${unassignedAmount.toStringAsFixed(2)} not assigned",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Tap to split evenly among participants',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),

              // Action button
              Icon(Icons.touch_app, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
