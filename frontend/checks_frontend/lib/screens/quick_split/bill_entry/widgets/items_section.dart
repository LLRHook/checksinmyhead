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
    // FIRST CHECK: Validate that a subtotal has been entered
    if (billData.subtotal <= 0) {
      widget.showSnackBar('Please enter a subtotal before adding items');
      // Provide haptic feedback for error
      HapticFeedback.vibrate();
      return;
    }

    final name = billData.itemNameController.text.trim();
    final priceText = billData.itemPriceController.text.trim();

    // Validate inputs
    if (name.isEmpty) {
      widget.showSnackBar('Please enter an item name');
      return;
    }

    if (priceText.isEmpty) {
      widget.showSnackBar('Please enter an item price');
      return;
    }

    double price = 0.0;
    try {
      price = double.parse(priceText);
    } catch (_) {
      // Show error for invalid number
      widget.showSnackBar('Please enter a valid price');
      return;
    }

    if (price <= 0) {
      widget.showSnackBar('Price must be greater than zero');
      return;
    }

    // Check if adding this item would exceed the subtotal
    final newTotalItems = billData.itemsTotal + price;
    if (billData.subtotal > 0 && newTotalItems > billData.subtotal) {
      // Show error message with remaining amount
      final remaining = (billData.subtotal - billData.itemsTotal)
          .toStringAsFixed(2);
      widget.showSnackBar(
        'Item price exceeds remaining amount. You can add up to \$$remaining',
      );
      return;
    }

    // Add item with haptic feedback
    HapticFeedback.mediumImpact();

    billData.addItem(name, price);
    billData.itemNameController.clear();
    billData.itemPriceController.clear();
    _updateAnimation(billData);

    // Focus back to the name field for quick entry of multiple items
    FocusScope.of(context).requestFocus(FocusNode());
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
    final brightness = Theme.of(context).brightness;

    // Precision threshold to account for floating point rounding errors
    const precisionThreshold = 0.01;

    // Define success color that works in both themes
    final successColor =
        brightness == Brightness.dark
            ? const Color(0xFF66BB6A) // Darker green for dark mode
            : const Color(0xFF4CAF50); // Normal green for light mode

    if ((value / subtotal) > 1.0 + (precisionThreshold / subtotal)) {
      return colorScheme.error;
    } else if ((subtotal - value).abs() <= precisionThreshold) {
      return successColor;
    } else if ((value / subtotal) > 0.9) {
      return colorScheme.primary;
    } else {
      return colorScheme.primary.withOpacity(0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final itemBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.white;

    final itemShadowColor =
        brightness == Brightness.dark
            ? Colors.black.withOpacity(0.15)
            : Colors.black.withOpacity(0.05);

    final progressBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceVariant.withOpacity(0.3)
            : Colors.grey.withOpacity(0.1);

    final dividerColor =
        brightness == Brightness.dark
            ? colorScheme.outline.withOpacity(0.3)
            : Colors.grey.shade300;

    // Check if the subtotal is set to enable/disable input fields
    final isSubtotalSet = billData.subtotal > 0;

    // Define field placeholder message based on subtotal status
    final itemNameHint =
        isSubtotalSet ? 'e.g., Pizza, Pasta, Salad' : 'Enter subtotal first';

    return SectionCard(
      title: 'Add Items',
      subTitle: 'Add items that add to your subtotal',

      icon: Icons.restaurant_menu,
      children: [
        // Item name field with premium styling
        TextFormField(
          controller: billData.itemNameController,
          decoration: AppInputDecoration.buildInputDecoration(
            context: context,
            labelText: 'Item name',
            hintText: itemNameHint,
            prefixIcon: Icons.fastfood,
          ),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          textCapitalization: TextCapitalization.sentences,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
          enabled: isSubtotalSet, // Disable if no subtotal
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
                  hintText: isSubtotalSet ? '0.00' : 'Enter subtotal first',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [CurrencyFormatter.currencyFormatter],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
                onFieldSubmitted: (_) => _addItem(billData),
                enabled: isSubtotalSet, // Disable if no subtotal
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56, // Match height with TextField
              child: ElevatedButton(
                onPressed:
                    isSubtotalSet
                        ? () => _addItem(billData)
                        : null, // Disable if no subtotal
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSubtotalSet
                          ? colorScheme.primary
                          : Colors.grey.withOpacity(0.3),
                  foregroundColor:
                      brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.9)
                          : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: isSubtotalSet ? 2 : 0,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),

        // Display a helper message when subtotal is not set
        if (!isSubtotalSet) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please enter a subtotal before adding items.',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

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
              Text('of', style: TextStyle(color: colorScheme.onSurface)),
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
              color: progressBgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate progress percentage capped at 100%
                final progressPercentage =
                    billData.subtotal > 0
                        ? (billData.animatedItemsTotal / billData.subtotal)
                            .clamp(0.0, 1.0)
                        : 0.0;

                return Stack(
                  children: [
                    // Progress bar
                    Container(
                      width: constraints.maxWidth * progressPercentage,
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
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Add "clear all" button
                if (billData.items.length > 1)
                  TextButton.icon(
                    onPressed: () {
                      // Show confirmation dialog
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text(
                                'Clear All Items?',
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                              content: Text(
                                'Are you sure you want to remove all items? This action cannot be undone.',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              backgroundColor:
                                  brightness == Brightness.dark
                                      ? colorScheme.surface
                                      : Colors.white,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CANCEL'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // Clear all items
                                    for (
                                      int i = billData.items.length - 1;
                                      i >= 0;
                                      i--
                                    ) {
                                      billData.removeItem(i);
                                    }
                                    _updateAnimation(billData);
                                    HapticFeedback.mediumImpact();
                                  },
                                  child: const Text('CLEAR ALL'),
                                ),
                              ],
                            ),
                      );
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text(
                      'CLEAR ALL',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
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
                    color: itemBgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: itemShadowColor,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Make the price container adaptable
                        Flexible(
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
                              overflow: TextOverflow.ellipsis,
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
