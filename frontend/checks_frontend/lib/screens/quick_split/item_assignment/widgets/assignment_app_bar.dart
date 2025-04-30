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

    return AppBar(
      title: const Text(
        'Assign Items',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: onBackPressed,
      ),
      actions: [
        if (showHelpButton && onHelpPressed != null)
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: onHelpPressed,
            tooltip: 'Show Tutorial',
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
