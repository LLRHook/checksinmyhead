import 'package:flutter/material.dart';
import 'package:checks_frontend/screens/recent_bills/models/recent_bill_model.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';

class BillSummaryCard extends StatelessWidget {
  final RecentBillModel bill;

  const BillSummaryCard({Key? key, required this.bill}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final cardBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.3)
            : Colors.grey.shade200;

    final headerBgColor =
        brightness == Brightness.dark
            ? colorScheme.primaryContainer.withOpacity(0.15)
            : colorScheme.primaryContainer.withOpacity(0.3);

    final headerTextColor = colorScheme.primary;

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.2)
            : Colors.grey.shade200;

    final tipBadgeBgColor =
        brightness == Brightness.dark
            ? colorScheme.primary.withOpacity(0.2)
            : colorScheme.primary.withOpacity(0.1);

    final textColor = colorScheme.onSurface;

    final totalTextColor = colorScheme.primary;

    return Card(
      elevation: 1,
      surfaceTintColor: cardBgColor,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: headerTextColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Bill Breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: headerTextColor,
                  ),
                ),
              ],
            ),
          ),

          // Bill details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  context,
                  'Subtotal',
                  bill.subtotal,
                  textColor: textColor,
                ),
                const SizedBox(height: 12),

                _buildDetailRow(context, 'Tax', bill.tax, textColor: textColor),

                if (bill.tipAmount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tip', style: TextStyle(color: textColor)),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.formatCurrency(bill.tipAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tipBadgeBgColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${bill.tipPercentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Divider(color: dividerColor),
                const SizedBox(height: 12),

                _buildDetailRow(
                  context,
                  'Total',
                  bill.total,
                  isTotal: true,
                  textColor: totalTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    double value, {
    bool isTotal = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: textColor,
          ),
        ),

        // Value
        Text(
          CurrencyFormatter.formatCurrency(value),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 18 : 14,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
