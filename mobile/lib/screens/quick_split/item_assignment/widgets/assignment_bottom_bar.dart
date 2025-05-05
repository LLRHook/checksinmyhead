import 'package:flutter/material.dart';

class AssignmentBottomBar extends StatelessWidget {
  final double totalBill;
  final VoidCallback onContinueTap;

  const AssignmentBottomBar({
    Key? key,
    required this.totalBill,
    required this.onContinueTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final backgroundColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Theme.of(context).scaffoldBackgroundColor;

    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.05);

    final labelColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withOpacity(0.7)
            : Colors.grey;

    final valueColor = colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bill total info - Keep fixed width
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Bill',
                style: TextStyle(fontSize: 12, color: labelColor),
              ),
              Text(
                '\$${totalBill.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor, // Theme-aware price color
                ),
              ),
            ],
          ),

          // Continue button - Position at the right
          ElevatedButton(
            onPressed: onContinueTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor:
                  brightness == Brightness.dark
                      ? Colors.black.withOpacity(
                        0.9,
                      ) // Better contrast in dark mode
                      : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 2,
              shadowColor: colorScheme.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
