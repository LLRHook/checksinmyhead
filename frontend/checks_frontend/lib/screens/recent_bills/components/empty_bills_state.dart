import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmptyBillsState extends StatelessWidget {
  const EmptyBillsState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final iconBgColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(
              0.2,
            ) // Slightly brighter in dark mode
            : colorScheme.primary.withOpacity(0.1);

    final iconColor = colorScheme.primary;

    final titleColor = colorScheme.onSurface;

    final subtitleColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withOpacity(
              0.8,
            ) // Slightly brighter for better readability
            : colorScheme.onSurface.withOpacity(0.7);

    // Button text color - for dark mode, use darker text on bright backgrounds for contrast
    final buttonTextColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(
              0.9,
            ) // Dark text for better contrast in dark mode
            : Colors.white;

    // Button shadow color
    final buttonShadowColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(0.6) // More visible in dark mode
            : colorScheme.primary.withOpacity(0.4);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium styled icon with subtle animation
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long, size: 40, color: iconColor),
            ),

            const SizedBox(height: 24),

            Text(
              'No bills yet',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Split bills with friends and track your expenses',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: subtitleColor),
            ),

            const SizedBox(height: 32),

            // Action button with premium styling
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context); // Return to create a new bill
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: buttonTextColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: buttonShadowColor,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
