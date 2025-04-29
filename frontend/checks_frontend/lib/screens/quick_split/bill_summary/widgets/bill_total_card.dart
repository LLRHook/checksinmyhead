import 'package:flutter/material.dart';
import '../models/bill_summary_data.dart';
import '/models/bill_item.dart';

class BillTotalCard extends StatelessWidget {
  final BillSummaryData data;

  const BillTotalCard({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                Icon(Icons.receipt_long, color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'BILL TOTAL',
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

            // Total amount
            Text(
              '\$${data.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Show all items - modern receipt format
            if (data.items.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Items',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),

              // Show all items without limitation
              for (int i = 0; i < data.items.length; i++)
                _buildItemRow(
                  data.items[i],
                  isLast: i == data.items.length - 1,
                ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],

            _buildBreakdownRow('Subtotal', data.subtotal),
            const SizedBox(height: 8),
            _buildBreakdownRow('Tax', data.tax),
            const SizedBox(height: 8),
            _buildBreakdownRow('Tip', data.tipAmount, showPercentage: true),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(BillItem item, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration:
          isLast
              ? null
              : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                ),
              ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(item.name, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            '\$${item.price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double amount, {
    bool showPercentage = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          showPercentage && label == 'Tip' && !data.isCustomTipAmount
              ? 'Tip (${data.tipPercentage.toStringAsFixed(0)}%)'
              : label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
