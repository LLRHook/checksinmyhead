import 'package:flutter/material.dart';

class UnassignedWarningDialog extends StatelessWidget {
  final double unassignedAmount;
  final VoidCallback onSplitEvenly;

  const UnassignedWarningDialog({
    super.key,
    required this.unassignedAmount,
    required this.onSplitEvenly,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Title
            const Text(
              'Unassigned Amount',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Content - Fixed dollar sign format
            Text(
              "There's still \$" + unassignedAmount.toStringAsFixed(2) + " unassigned. Would you like to split it evenly among all participants?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16, 
                color: Colors.grey.shade700,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Continue Anyway',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Split evenly button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onSplitEvenly();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Split Evenly',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    builder: (context) => UnassignedWarningDialog(
      unassignedAmount: unassignedAmount,
      onSplitEvenly: onSplitEvenly,
    ),
  );
}