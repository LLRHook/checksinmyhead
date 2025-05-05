import 'package:flutter/material.dart';
import '../models/bill_summary_data.dart';
import '/models/bill_item.dart';

class BillTotalCard extends StatefulWidget {
  final BillSummaryData data;
  final bool initiallyExpandedItems;
  final bool initiallyExpandedCostBreakdown;

  const BillTotalCard({
    Key? key,
    required this.data,
    this.initiallyExpandedItems = true,
    this.initiallyExpandedCostBreakdown = true,
  }) : super(key: key);

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

  void _toggleItemsExpanded() {
    setState(() {
      _isItemsExpanded = !_isItemsExpanded;
      if (_isItemsExpanded) {
        _itemsController.forward();
      } else {
        _itemsController.reverse();
      }
    });
  }

  void _toggleCostBreakdownExpanded() {
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

    // Theme-aware colors
    final cardBackgroundColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    final cardBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.3)
            : Colors.grey.shade200;

    final titleColor = colorScheme.primary;

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.2)
            : Colors.grey.shade200;

    final expandIconColor =
        brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600;

    final itemBorderColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.1)
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
                            color:
                                colorScheme.onSurface, // Theme-aware text color
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
                            // Show all items without limitation
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cost Breakdown',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              colorScheme.onSurface, // Theme-aware text color
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

  Widget _buildItemRow(
    BuildContext context,
    BillItem item, {
    bool isLast = false,
    required Brightness brightness,
    required Color itemBorderColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate total including alcohol costs
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
                          color:
                              colorScheme.onSurface, // Theme-aware text color
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
                  color: colorScheme.onSurface, // Theme-aware text color
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    double amount, {
    bool showPercentage = false,
    bool isBold = false,
    double fontSize = 14,
    Color? textColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Set default text color if none provided, based on theme
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
