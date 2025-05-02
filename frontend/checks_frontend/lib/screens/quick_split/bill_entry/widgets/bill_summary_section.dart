import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill_data.dart';

class BillSummarySection extends StatelessWidget {
  const BillSummarySection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final borderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.3)
            : Colors.grey.shade200;

    return Card(
      elevation: 0,
      color:
          brightness == Brightness.dark
              ? colorScheme.surfaceContainerHighest
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
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
            _buildBreakdownRow(context, 'Subtotal', billData.subtotal),
            const SizedBox(height: 8),
            _buildBreakdownRow(context, 'Tax', billData.tax),

            if (billData.tipAmount > 0) ...[
              const SizedBox(height: 8),
              _buildBreakdownRow(
                context,
                _getTipLabel(billData),
                billData.tipAmount,
                showPercentage: !billData.useCustomTipAmount,
                tipPercentage: billData.tipPercentage,
              ),
            ],

            // Total row with divider
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outline.withOpacity(
                0.3,
              ), // Theme-aware divider
            ),
            const SizedBox(height: 12),
            _buildBreakdownRow(
              context,
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
    BuildContext context,
    String label,
    double value, {
    bool isBold = false,
    double? fontSize,
    Color? textColor,
    bool showPercentage = false,
    double? tipPercentage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // Default text color that respects theme
    final defaultTextColor = colorScheme.onSurface;

    return Row(
      children: [
        // Left side - the label
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: textColor ?? defaultTextColor,
          ),
        ),

        // Spacer to push the price to the right
        const Spacer(),

        // Right side - the value
        Text(
          '\$${value.toStringAsFixed(2)}${showPercentage && tipPercentage != null ? ' (${tipPercentage.toInt()}%)' : ''}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: textColor ?? defaultTextColor,
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
