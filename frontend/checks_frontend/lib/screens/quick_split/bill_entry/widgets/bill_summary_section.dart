import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill_data.dart';

class BillSummarySection extends StatelessWidget {
  const BillSummarySection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primaryContainer.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Premium title with icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.summarize,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Bill Summary',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Premium summary rows
          _buildSummaryRow(
            label: 'Subtotal',
            value: billData.subtotal,
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 10),

          _buildSummaryRow(
            label: 'Tax',
            value: billData.tax,
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 10),

          _buildSummaryRow(
            label: _getTipLabel(billData),
            value: billData.tipAmount,
            colorScheme: colorScheme,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1),
          ),

          // Premium total row
          Row(
            children: [
              // Left side - the TOTAL label
              const Text(
                'TOTAL',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              // Spacer to push the price to the right
              const Spacer(),
              // Right side - the price in container with fixed width
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${billData.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build consistent summary rows
  Widget _buildSummaryRow({
    required String label,
    required double value,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        // Use Expanded instead of Flexible to force the label to take available space
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Use a fixed width SizedBox for the value to ensure consistency
        SizedBox(
          width:
              80, // Fixed width for the price that should be enough for any reasonable value
          child: Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
            textAlign:
                TextAlign.right, // Right align text within the fixed width
          ),
        ),
      ],
    );
  }

  // Helper method to get the appropriate tip label
  String _getTipLabel(BillData billData) {
    if (billData.useCustomTipAmount) {
      return 'Tip (Custom)';
    } else if (billData.useDifferentTipForAlcohol) {
      return 'Tip (Food/Alcohol)';
    } else {
      return 'Tip (${billData.tipPercentage.toInt()}%)';
    }
  }
}
