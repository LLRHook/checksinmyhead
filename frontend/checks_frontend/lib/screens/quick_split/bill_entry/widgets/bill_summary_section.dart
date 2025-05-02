import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill_data.dart';

class BillSummarySection extends StatelessWidget {
  const BillSummarySection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Title with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.summarize, color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'BILL SUMMARY',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Premium summary rows
            _buildBreakdownRow('Subtotal', billData.subtotal),

            const SizedBox(height: 8),

            _buildBreakdownRow('Tax', billData.tax),

            if (billData.tipAmount > 0) ...[
              const SizedBox(height: 8),
              _buildBreakdownRow(
                _getTipLabel(billData),
                billData.tipAmount,
                showPercentage: !billData.useCustomTipAmount,
                tipPercentage: billData.tipPercentage,
              ),
            ],
            // Total row with divider
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            _buildBreakdownRow(
              'Total',
              billData.total,
              isBold: true,
              fontSize: 16,
              textColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build consistent breakdown rows
  Widget _buildBreakdownRow(
    String label,
    double value, {
    bool isBold = false,
    double? fontSize,
    Color? textColor,
    bool showPercentage = false,
    double? tipPercentage,
  }) {
    return Row(
      children: [
        // Left side - the label
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: textColor,
          ),
        ),
        // Spacer to push the price to the right
        const Spacer(),
        // Right side - the value
        Text(
          '\$${value.toStringAsFixed(2)}' +
              (showPercentage && tipPercentage != null
                  ? ' (${tipPercentage.toInt()}%)'
                  : ''),
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: textColor,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  // Helper method to get the appropriate tip label
  String _getTipLabel(BillData billData) {
    if (billData.useCustomTipAmount) {
      return 'Tip (Custom)';
    } else if (billData.useDifferentTipForAlcohol) {
      return 'Tip (Food)';
    } else {
      return 'Tip';
    }
  }
}
