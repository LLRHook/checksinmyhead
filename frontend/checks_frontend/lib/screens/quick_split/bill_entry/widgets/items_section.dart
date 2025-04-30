import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/bill_data.dart';
import '../components/section_card.dart';
import '../components/input_decoration.dart';
import '../utils/currency_formatter.dart';

class ItemsSection extends StatefulWidget {
  final Function(String) showSnackBar;

  const ItemsSection({Key? key, required this.showSnackBar}) : super(key: key);

  @override
  State<ItemsSection> createState() => _ItemsSectionState();
}

class _ItemsSectionState extends State<ItemsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _progressAnimation.addListener(() {
      final billData = Provider.of<BillData>(context, listen: false);
      billData.updateAnimatedItemsTotal(_progressAnimation.value);
    });
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _updateAnimation(BillData billData) {
    // Only animate if there's a significant change
    if ((billData.itemsTotal - billData.animatedItemsTotal).abs() > 0.01) {
      // Update the animation with new values
      _progressAnimation = Tween<double>(
        begin: billData.animatedItemsTotal,
        end: billData.itemsTotal,
      ).animate(
        CurvedAnimation(
          parent: _progressAnimationController,
          curve: Curves.easeInOut,
        ),
      );

      // Reset and start the animation
      _progressAnimationController.reset();
      _progressAnimationController.forward();
    }
  }

  void _addItem(BillData billData) {
    final name = billData.itemNameController.text.trim();
    final priceText = billData.itemPriceController.text.trim();

    if (name.isNotEmpty && priceText.isNotEmpty) {
      double price = 0.0;
      try {
        price = double.parse(priceText);
      } catch (_) {
        // Show error for invalid number
        widget.showSnackBar('Please enter a valid price');
        return;
      }

      if (price > 0) {
        // Check if adding this item would exceed the subtotal
        final newTotalItems = billData.itemsTotal + price;
        if (newTotalItems > billData.subtotal) {
          // Show error message
          widget.showSnackBar(
            'Item total (\$${newTotalItems.toStringAsFixed(2)}) would exceed the subtotal (\$${billData.subtotal.toStringAsFixed(2)})',
          );
          return;
        }

        // Add item with haptic feedback
        HapticFeedback.mediumImpact();

        billData.addItem(name, price);
        billData.itemNameController.clear();
        billData.itemPriceController.clear();
        _updateAnimation(billData);
      }
    }
  }

  void _removeItem(BillData billData, int index) {
    // Provide haptic feedback for item removal
    HapticFeedback.mediumImpact();
    billData.removeItem(index);
    _updateAnimation(billData);
  }

  // Get color for progress indicator
  Color _getProgressColor(BuildContext context, double value, double subtotal) {
    final colorScheme = Theme.of(context).colorScheme;

    // The 0.99 threshold accounts for floating point rounding errors
    if ((value / subtotal) > 1.0) {
      return colorScheme.error;
    } else if ((value / subtotal) >= 0.99) {
      return const Color(0xFF4CAF50); // Material Green
    } else {
      return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      title: 'Add Items (Optional)',
      subTitle: 'Adding items helps assign specific dishes to people',
      icon: Icons.restaurant_menu,
      children: [
        // Item name field with premium styling
        TextFormField(
          controller: billData.itemNameController,
          decoration: AppInputDecoration.buildInputDecoration(
            context: context,
            labelText: 'Item name',
            hintText: 'e.g., Pizza, Pasta, Salad',
            prefixIcon: Icons.fastfood,
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 16),

        // Item price field with add button - premium styling
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: billData.itemPriceController,
                decoration: AppInputDecoration.buildInputDecoration(
                  context: context,
                  labelText: 'Item price',
                  prefixText: '\$',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [CurrencyFormatter.currencyFormatter],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56, // Match height with TextField
              child: ElevatedButton(
                onPressed: () => _addItem(billData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Progress indicator showing items total vs subtotal - premium styling
        if (billData.items.isNotEmpty && billData.subtotal > 0) ...[
          Row(
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback:
                    (Rect bounds) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _getProgressColor(
                          context,
                          billData.animatedItemsTotal,
                          billData.subtotal,
                        ),
                        _getProgressColor(
                          context,
                          billData.animatedItemsTotal,
                          billData.subtotal,
                        ).withOpacity(0.8),
                      ],
                    ).createShader(bounds),
                child: Text(
                  'Items: \$${billData.animatedItemsTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('of'),
              const SizedBox(width: 4),
              Text(
                '\$${billData.subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              // Animated percentage with premium styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getProgressColor(
                    context,
                    billData.animatedItemsTotal,
                    billData.subtotal,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(billData.animatedItemsTotal / billData.subtotal * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _getProgressColor(
                      context,
                      billData.animatedItemsTotal,
                      billData.subtotal,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Premium animated progress indicator with gradient and rounded caps
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      width:
                          constraints.maxWidth *
                          (billData.subtotal > 0
                              ? (billData.animatedItemsTotal /
                                      billData.subtotal)
                                  .clamp(0.0, 1.0)
                              : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            _getProgressColor(
                              context,
                              billData.animatedItemsTotal,
                              billData.subtotal,
                            ),
                            _getProgressColor(
                              context,
                              billData.animatedItemsTotal,
                              billData.subtotal,
                            ).withOpacity(0.8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getProgressColor(
                              context,
                              billData.animatedItemsTotal,
                              billData.subtotal,
                            ).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Only show items list if there are items
          if (billData.items.isNotEmpty) ...[
            const SizedBox(height: 20),

            // Premium styled items list
            Row(
              children: [
                Icon(
                  Icons.format_list_bulleted,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Added Items',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...List.generate(billData.items.length, (index) {
              final item = billData.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Make the price container adaptable
                        Flexible(
                          // Add this Flexible wrapper
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${item.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis, // Add this
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete button with premium styling
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _removeItem(billData, index),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }
}
