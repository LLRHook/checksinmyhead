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
    
    // Check if items match subtotal (with small tolerance for rounding errors)
    final isItemsMatchingSubtotal = billData.subtotal > 0 && 
        (billData.subtotal - billData.itemsTotal).abs() <= 0.01;
    
    // Determine button appearance based on validation state
    final buttonColor = isItemsMatchingSubtotal ? 
        const Color(0xFF4CAF50) : // Green when matching
        colorScheme.primary;
    
    final buttonIcon = isItemsMatchingSubtotal ? 
        Icons.check_circle : 
        Icons.arrow_forward;
    
    // Create shimmer effect for the button when items match
    final hasItems = billData.items.isNotEmpty;
    
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
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
              const Icon(Icons.check_circle, size: 20),
              const SizedBox(width: 8),
              const Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ] else if (hasItems) ...[
              Text(
                'CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: Colors.white.withOpacity(0.9),
              ),
            ] else ...[
              const Text(
                'ADD ITEMS & CONTINUE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}