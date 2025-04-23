import 'package:flutter/material.dart';

class UnassignedWarningDialog extends StatelessWidget {
  final double unassignedAmount;
  final VoidCallback onSplitEvenly;

  const UnassignedWarningDialog({
    Key? key,
    required this.unassignedAmount,
    required this.onSplitEvenly,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unassigned Amount'),
      content: Text(
        'There\'s still \$${unassignedAmount.toStringAsFixed(2)} unassigned. '
        'Would you like to split it evenly?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onSplitEvenly();
          },
          child: const Text('Split Evenly'),
        ),
      ],
    );
  }
}

// Function to show the unassigned warning dialog
void showUnassignedWarningDialog({
  required BuildContext context,
  required double unassignedAmount,
  required VoidCallback onSplitEvenly,
}) {
  showDialog(
    context: context,
    builder:
        (context) => UnassignedWarningDialog(
          unassignedAmount: unassignedAmount,
          onSplitEvenly: onSplitEvenly,
        ),
  );
}
