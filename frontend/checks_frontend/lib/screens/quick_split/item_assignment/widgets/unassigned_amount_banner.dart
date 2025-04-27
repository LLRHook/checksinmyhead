import 'package:flutter/material.dart';

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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSplitEvenly,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Warning icon
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                
                const SizedBox(width: 12),
                
                // Warning text - Fixed dollar sign format
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "\$" + unassignedAmount.toStringAsFixed(2) + " not assigned",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Tap to split evenly among participants',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action button
                Icon(
                  Icons.touch_app,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}