import 'package:flutter/material.dart';
import '../../models/bill_data.dart';

class AlcoholSummaryCard extends StatelessWidget {
  final BillData billData;
  final double previousAmount;

  const AlcoholSummaryCard({
    Key? key,
    required this.billData,
    required this.previousAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (billData.items.isEmpty) {
      return SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.tertiary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.liquor, size: 20, color: colorScheme.tertiary),
              SizedBox(width: 8),
              Text(
                'Alcohol Summary',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alcohol Subtotal:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              // Animated value with TweenAnimationBuilder
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(
                  begin: previousAmount,
                  end: billData.alcoholAmount,
                ),
                builder: (context, value, _) {
                  return Text(
                    '\$${value.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Percentage of Bill:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              // Animated percentage
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(
                  begin:
                      billData.subtotal > 0
                          ? ((previousAmount / billData.subtotal) * 100)
                          : 0,
                  end:
                      billData.subtotal > 0
                          ? ((billData.alcoholAmount / billData.subtotal) * 100)
                          : 0,
                ),
                builder: (context, value, _) {
                  return Text(
                    '${value.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  );
                },
              ),
            ],
          ),

          // Add alcohol tax row
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alcohol Tax:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '\$${billData.alcoholTax.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),

          // Show tip information if different tip for alcohol is enabled
          if (billData.useDifferentTipForAlcohol) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  billData.useCustomAlcoholTipAmount
                      ? 'Alcohol Tip (Custom):'
                      : 'Alcohol Tip (${billData.alcoholTipPercentage.toInt()}%):',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '\$${billData.alcoholTipAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],

          // Add total alcohol section (subtotal + tax + tip)
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alcohol Total:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  ),
                ),
                Text(
                  '\$${(billData.alcoholAmount + billData.alcoholTax + billData.alcoholTipAmount).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
