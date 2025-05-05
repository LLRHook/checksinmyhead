import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// BillSummarySection - Displays a summary card of the bill's financial details
///
/// Shows a cleanly formatted breakdown of the bill including subtotal, tax,
/// tip (with percentage or custom indication), and total. Uses theme-aware
/// styling to maintain visual consistency in both light and dark modes.
///
/// The component:
/// - Automatically updates when bill data changes (via Provider)
/// - Adapts colors and styling based on the current theme
/// - Formats currency values consistently
/// - Shows appropriate tip information based on whether percentage or custom tip is used
class BillSummarySection extends StatelessWidget {
  const BillSummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Border color adapts to theme - more visible in dark mode
    final borderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .3)
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
            // Header with title and icon
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

            // Bill breakdown rows
            _buildBreakdownRow(context, 'Subtotal', billData.subtotal),
            const SizedBox(height: 8),
            _buildBreakdownRow(context, 'Tax', billData.tax),

            // Only show tip row if amount is greater than zero
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

            // Total row with visual separator
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.3),
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

  /// Creates a consistent row layout for each bill component
  ///
  /// Displays a label on the left and the monetary value on the right
  /// with optional formatting for the total row and tip percentage.
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
    final defaultTextColor = colorScheme.onSurface;

    return Row(
      children: [
        // Label text (left-aligned)
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: textColor ?? defaultTextColor,
          ),
        ),

        // Flexible space to push amount to right edge
        const Spacer(),

        // Amount value (right-aligned) with optional percentage
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

  /// Determines appropriate tip label based on tip mode
  ///
  /// Returns "Tip (Custom)" for manually entered amounts,
  /// or just "Tip" for percentage-based amounts
  String _getTipLabel(BillData billData) {
    if (billData.useCustomTipAmount) {
      return 'Tip (Custom)';
    } else {
      return 'Tip';
    }
  }
}
