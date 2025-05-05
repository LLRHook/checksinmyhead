import 'package:flutter/material.dart';

/// SectionCard - Reusable card widget for displaying grouped content sections
///
/// Creates a visually distinct card with a title, optional subtitle, and icon
/// that contains a collection of related widgets. Used for organizing content
/// into logical sections with consistent styling across the app.
///
/// Inputs:
///   - title: Section heading text
///   - subTitle: Optional descriptive text displayed below the title
///   - icon: Icon displayed in a colored container beside the title
///   - children: List of widgets to display as the section's content
///
/// Visual characteristics:
///   - Rounded corners with subtle elevation shadow
///   - Title with accompanying icon in a colored badge
///   - Theme-aware colors that adapt to light/dark mode
class SectionCard extends StatelessWidget {
  final String title;
  final String? subTitle;
  final IconData icon;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.title,
    this.subTitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors that adapt to light/dark mode
    final backgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    // Shadow is more prominent in dark mode for better visibility
    final shadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .2)
            : Colors.black.withValues(alpha: .05);

    // Subtitle uses semi-transparent color for subtle visual hierarchy
    final subtitleColor =
        brightness == Brightness.dark
            ? colorScheme.onSurface.withValues(alpha: .6)
            : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with icon badge and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),

          // Optional subtitle with left padding to align with title text
          if (subTitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                subTitle!,
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Section content widgets
          ...children,
        ],
      ),
    );
  }
}
