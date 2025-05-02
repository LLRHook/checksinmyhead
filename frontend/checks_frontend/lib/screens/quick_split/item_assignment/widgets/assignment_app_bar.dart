import 'package:flutter/material.dart';

class AssignmentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBackPressed;
  final VoidCallback? onHelpPressed;
  final bool showHelpButton;

  const AssignmentAppBar({
    Key? key,
    required this.onBackPressed,
    this.onHelpPressed,
    this.showHelpButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final backgroundColor = colorScheme.surface;
    final iconColor = colorScheme.onSurface;

    return AppBar(
      title: Text(
        'Assign Items',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface, // Theme-aware text color
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: backgroundColor,
      foregroundColor: iconColor, // Theme-aware icons and text
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: onBackPressed,
        color: iconColor, // Ensure icon respects theme
      ),
      actions: [
        if (showHelpButton && onHelpPressed != null)
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: onHelpPressed,
            tooltip: 'Show Tutorial',
            color: colorScheme.primary, // Use primary color for help icon
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
