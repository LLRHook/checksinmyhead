import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill_data.dart';

class ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ContinueButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Check if items match subtotal (with small tolerance for rounding errors)
    final isItemsMatchingSubtotal =
        billData.subtotal > 0 &&
        (billData.subtotal - billData.itemsTotal).abs() <= 0.01;

    // Theme-aware success color
    final successColor =
        brightness == Brightness.dark
            ? const Color(0xFF66BB6A) // Darker green for dark mode
            : const Color(0xFF4CAF50); // Normal green for light mode

    // Determine button appearance based on validation state
    final buttonColor =
        isItemsMatchingSubtotal ? successColor : colorScheme.primary;

    final buttonIcon =
        isItemsMatchingSubtotal ? Icons.check_circle : Icons.arrow_forward;

    // Button text color
    final textColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(
              0.9,
            ) // Dark text for better contrast in dark mode
            : Colors.white;

    // Has items check
    final hasItems = billData.items.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(
              brightness == Brightness.dark ? 0.2 : 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isItemsMatchingSubtotal) ...[
              Icon(Icons.check_circle, size: 20, color: textColor),
              const SizedBox(width: 8),
              Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: textColor,
                ),
              ),
            ] else if (hasItems) ...[
              Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: textColor.withOpacity(0.9),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: textColor.withOpacity(0.9),
              ),
            ] else ...[
              Text(
                'ADD ITEMS & CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
