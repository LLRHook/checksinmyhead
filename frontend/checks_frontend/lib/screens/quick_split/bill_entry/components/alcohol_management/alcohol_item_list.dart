import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'alcohol_summary_card.dart';

class AlcoholItemList extends StatefulWidget {
  final BillData billData;
  final Function(bool)? onItemToggled;

  const AlcoholItemList({Key? key, required this.billData, this.onItemToggled})
    : super(key: key);

  @override
  State<AlcoholItemList> createState() => _AlcoholItemListState();
}

class _AlcoholItemListState extends State<AlcoholItemList> {
  // Keep track of previous alcohol amount to animate transitions
  double _previousAlcoholAmount = 0.0;

  @override
  void initState() {
    super.initState();

    // Delay getting the alcohol amount to allow Provider to be initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previousAlcoholAmount = widget.billData.alcoholAmount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final billData = widget.billData;
    final colorScheme = Theme.of(context).colorScheme;

    // Update previous amount when needed, but outside of build for animation
    if ((billData.alcoholAmount - _previousAlcoholAmount).abs() > 0.01) {
      // Only update this after the UI is built to prevent animation issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _previousAlcoholAmount = billData.alcoholAmount;
        });
      });
    }

    if (billData.items.isEmpty) {
      return _buildEmptyItemsMessage();
    }

    return Column(
      children: [
        ..._buildTapableItemsList(billData, colorScheme),

        // Add summary card
        AlcoholSummaryCard(
          billData: billData,
          previousAmount: _previousAlcoholAmount,
        ),
      ],
    );
  }

  Widget _buildEmptyItemsMessage() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 40, color: Colors.grey.shade500),
          SizedBox(height: 16),
          Text(
            'No items added yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Add items on the main screen first, then come back here to mark alcoholic items',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTapableItemsList(
    BillData billData,
    ColorScheme colorScheme,
  ) {
    final List<Widget> itemWidgets = [];

    for (int i = 0; i < billData.items.length; i++) {
      final item = billData.items[i];

      // Use AnimatedContainer for fluid transitions
      itemWidgets.add(
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0.95, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: GestureDetector(
            onTap: () {
              // Toggle the item's alcohol status
              billData.toggleItemAlcohol(i, !item.isAlcohol);
              HapticFeedback.selectionClick();

              // Notify parent of change if callback provided
              if (widget.onItemToggled != null) {
                // Check if any items are now alcoholic
                bool hasAnyAlcoholicItems = billData.items.any(
                  (item) => item.isAlcohol,
                );
                widget.onItemToggled!(hasAnyAlcoholicItems);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color:
                    item.isAlcohol
                        ? colorScheme.tertiary.withOpacity(0.1)
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      item.isAlcohol
                          ? colorScheme.tertiary
                          : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Animated icon container
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            item.isAlcohol
                                ? colorScheme.tertiary
                                : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Icon(
                            item.isAlcohol ? Icons.wine_bar : Icons.fastfood,
                            key: ValueKey<bool>(item.isAlcohol),
                            color:
                                item.isAlcohol
                                    ? Colors.white
                                    : Colors.grey.shade500,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),

                    // Item details with animated text color
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color:
                                  item.isAlcohol
                                      ? colorScheme.tertiary
                                      : Colors.black,
                            ),
                            child: Text(item.name),
                          ),
                          SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color:
                                  item.isAlcohol
                                      ? colorScheme.tertiary.withOpacity(0.8)
                                      : Colors.grey.shade600,
                            ),
                            child: Text('\$${item.price.toStringAsFixed(2)}'),
                          ),
                        ],
                      ),
                    ),

                    // Animated check indicator
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (
                        Widget child,
                        Animation<double> animation,
                      ) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child:
                          item.isAlcohol
                              ? Container(
                                key: const ValueKey<bool>(true),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              )
                              : SizedBox(
                                key: const ValueKey<bool>(false),
                                width: 24,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return itemWidgets;
  }
}
