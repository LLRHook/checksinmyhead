import 'package:flutter/material.dart';

class UnassignedAmountBanner extends StatelessWidget {
  final double unassignedAmount;
  final VoidCallback onSplitEvenly;

  const UnassignedAmountBanner({
    Key? key,
    required this.unassignedAmount,
    required this.onSplitEvenly,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Unassigned: \$${unassignedAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onSplitEvenly,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.withOpacity(0.2),
              foregroundColor: Colors.amber[700],
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.amber[700]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Split Remaining Items Evenly',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
