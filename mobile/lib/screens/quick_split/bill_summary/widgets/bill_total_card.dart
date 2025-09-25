// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:checks_frontend/screens/quick_split/bill_summary/models/bill_summary_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/bill_item.dart';

/// BillTotalCard - Displays bill total with expandable sections for items and breakdown
///
/// Shows the total bill amount with collapsible sections for itemized costs
/// and a detailed cost breakdown (subtotal, tax, tip).
class BillTotalCard extends StatefulWidget {
  final BillSummaryData data;
  final bool initiallyExpandedItems;
  final bool initiallyExpandedCostBreakdown;

  const BillTotalCard({
    super.key,
    required this.data,
    this.initiallyExpandedItems = true,
    this.initiallyExpandedCostBreakdown = true,
  });

  @override
  State<BillTotalCard> createState() => _BillTotalCardState();
}

class _BillTotalCardState extends State<BillTotalCard>
    with TickerProviderStateMixin {
  late bool _isItemsExpanded;
  late bool _isCostBreakdownExpanded;
  late AnimationController _itemsController;
  late AnimationController _costBreakdownController;
  late Animation<double> _itemsIconTurns;
  late Animation<double> _costBreakdownIconTurns;

  // Animation curves for smooth transitions
  static final Animatable<double> _easeInTween = CurveTween(
    curve: Curves.easeIn,
  );
  static final Animatable<double> _halfTween = Tween<double>(
    begin: 0.0,
    end: 0.5,
  );

  @override
  void initState() {
    super.initState();
    _isItemsExpanded = widget.initiallyExpandedItems;
    _isCostBreakdownExpanded = widget.initiallyExpandedCostBreakdown;

    _itemsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _costBreakdownController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _itemsIconTurns = _itemsController.drive(_halfTween.chain(_easeInTween));
    _costBreakdownIconTurns = _costBreakdownController.drive(
      _halfTween.chain(_easeInTween),
    );

    // Initialize animation states based on expansion
    if (_isItemsExpanded) {
      _itemsController.value = 1.0;
    }

    if (_isCostBreakdownExpanded) {
      _costBreakdownController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _itemsController.dispose();
    _costBreakdownController.dispose();
    super.dispose();
  }

  /// Toggles the expansion state of the items section
  void _toggleItemsExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isItemsExpanded = !_isItemsExpanded;
      if (_isItemsExpanded) {
        _itemsController.forward();
      } else {
        _itemsController.reverse();
      }
    });
  }

  /// Toggles the expansion state of the cost breakdown section
  void _toggleCostBreakdownExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isCostBreakdownExpanded = !_isCostBreakdownExpanded;
      if (_isCostBreakdownExpanded) {
        _costBreakdownController.forward();
      } else {
        _costBreakdownController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors for light/dark mode support
    final cardBackgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: 0.3)
            : Colors.grey.shade200;

    final titleColor = colorScheme.primary;

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .2)
            : Colors.grey.shade200;

    final expandIconColor =
        brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600;

    final itemBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withValues(alpha: .1)
            : Colors.grey.shade100;

    return Card(
      elevation: 0,
      color: cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Title with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, color: titleColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'BILL TOTAL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Total amount
            Text(
              '\$${widget.data.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: dividerColor),
            const SizedBox(height: 16),

            // Items section with collapsible content
            if (widget.data.items.isNotEmpty) ...[
              // Clickable Items header
              InkWell(
                onTap: _toggleItemsExpanded,
                borderRadius: BorderRadius.circular(8),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      RotationTransition(
                        turns: _itemsIconTurns,
                        child: Icon(
                          Icons.expand_more,
                          color: expandIconColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Animated expandable items list
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child:
                    _isItemsExpanded
                        ? Column(
                          children: [
                            for (int i = 0; i < widget.data.items.length; i++)
                              _buildItemRow(
                                context,
                                widget.data.items[i],
                                isLast: i == widget.data.items.length - 1,
                                brightness: brightness,
                                itemBorderColor: itemBorderColor,
                              ),
                          ],
                        )
                        : const SizedBox.shrink(),
              ),

              const SizedBox(height: 8),
              Divider(height: 1, thickness: 1, color: dividerColor),
              const SizedBox(height: 16),
            ],

            // Cost Breakdown section
            InkWell(
              onTap: _toggleCostBreakdownExpanded,
              borderRadius: BorderRadius.circular(8),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Breakdown',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _costBreakdownIconTurns,
                      child: Icon(
                        Icons.expand_more,
                        color: expandIconColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Animated expandable cost breakdown
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child:
                  _isCostBreakdownExpanded
                      ? Column(
                        children: [
                          _buildBreakdownRow(
                            context,
                            'Subtotal',
                            widget.data.subtotal,
                          ),
                          const SizedBox(height: 8),

                          if (widget.data.tax > 0) ...[
                            _buildBreakdownRow(context, 'Tax', widget.data.tax),
                            const SizedBox(height: 8),
                          ],

                          if (widget.data.tipAmount > 0) ...[
                            _buildBreakdownRow(
                              context,
                              'Tip',
                              widget.data.tipAmount,
                              showPercentage: true,
                            ),
                          ],
                        ],
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a row for an individual bill item
  Widget _buildItemRow(
    BuildContext context,
    BillItem item, {
    bool isLast = false,
    required Brightness brightness,
    required Color itemBorderColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalItemCost = item.price;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration:
          isLast
              ? null
              : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: itemBorderColor, width: 1),
                ),
              ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${totalItemCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a row for the cost breakdown section (subtotal, tax, tip)
  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    double amount, {
    bool showPercentage = false,
    bool isBold = false,
    double fontSize = 14,
    Color? textColor,
  }) {
    final brightness = Theme.of(context).brightness;

    final defaultTextColor =
        brightness == Brightness.dark
            ? Colors.grey.shade300
            : Colors.grey.shade800;

    final effectiveTextColor = textColor ?? defaultTextColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          showPercentage && label == 'Tip' && !widget.data.isCustomTipAmount
              ? 'Tip (${widget.data.tipPercentage.toStringAsFixed(0)}%)'
              : label,
          style: TextStyle(
            fontSize: fontSize,
            color: effectiveTextColor,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: effectiveTextColor,
          ),
        ),
      ],
    );
  }
}
