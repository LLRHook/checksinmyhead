// Checkmate: Privacy-first receipt spliting
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

import 'package:checks_frontend/config/dialogUtils/dialog_utils.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/components/input_decoration.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/components/section_card.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/models/bill_data.dart';
import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// ItemsSection - Interactive section for adding and managing bill line items
///
/// Provides a complete interface for entering, tracking, and managing bill items.
/// Features animated progress tracking, collapsible item lists, and real-time validation.
///
/// Purpose:
///   - Allow users to itemize their bill with individual items and prices
///   - Display a progress indicator showing how much of the subtotal has been itemized
///   - Provide visual feedback on input validation and subtotal matching status
///
/// Inputs:
///   - showSnackBar: Function to display temporary notification messages
///
/// Side effects:
///   - Updates the BillData provider with new items
///   - Provides haptic feedback for user interactions
class ItemsSection extends StatefulWidget {
  final Function(String) showSnackBar;

  const ItemsSection({super.key, required this.showSnackBar});

  @override
  State<ItemsSection> createState() => _ItemsSectionState();
}

class _ItemsSectionState extends State<ItemsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  // Tracks whether the items list is shown in full or collapsed state
  bool _isItemsListCollapsed = false;

  // Maximum number of items to show when the list is collapsed
  final int _maxVisibleItemsWhenCollapsed = 3;

  @override
  void initState() {
    super.initState();

    // Set up animation for smooth transitions in the progress indicator
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

    // Update the BillData model whenever the animation updates
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

  /// Updates the progress animation when items total changes
  ///
  /// Only starts a new animation if there's a significant change to prevent
  /// unnecessary animations for small rounding differences.
  void _updateAnimation(BillData billData) {
    // Only animate if there's a significant change (greater than 1 cent)
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

  /// Adds a new item to the bill with validation
  ///
  /// Performs multiple validation checks:
  /// - Ensures subtotal has been entered
  /// - Validates item name and price are provided
  /// - Ensures price is a valid positive number
  /// - Checks that adding the item won't exceed the subtotal
  void _addItem(BillData billData) {
    // First check: Validate that a subtotal has been entered
    if (billData.subtotal <= 0) {
      widget.showSnackBar('Please enter a subtotal before adding items');
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

    // Auto-expand list when adding new items
    if (_isItemsListCollapsed &&
        billData.items.length > _maxVisibleItemsWhenCollapsed) {
      setState(() {
        _isItemsListCollapsed = false;
      });
    }

    // Clear focus for a better user experience
    FocusScope.of(context).requestFocus(FocusNode());
  }

  /// Removes an item from the bill
  void _removeItem(BillData billData, int index) {
    HapticFeedback.mediumImpact();
    billData.removeItem(index);
    _updateAnimation(billData);
  }

  /// Determines progress indicator color based on completion percentage
  ///
  /// Returns different colors based on how close the items total is to the subtotal:
  /// - Red when over the subtotal
  /// - Green when exactly matching the subtotal
  /// - Primary color variations when approaching completion
  Color _getProgressColor(BuildContext context, double value, double subtotal) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Small threshold to account for floating point imprecision
    const precisionThreshold = 0.01;

    // Theme-aware success color
    final successColor =
        brightness == Brightness.dark
            ? const Color(0xFF66BB6A) // Darker green for dark mode
            : const Color(0xFF4CAF50); // Normal green for light mode

    if ((value / subtotal) > 1.0 + (precisionThreshold / subtotal)) {
      return colorScheme.error; // Over subtotal - show error color
    } else if ((subtotal - value).abs() <= precisionThreshold) {
      return successColor; // Exact match - show success color
    } else if ((value / subtotal) > 0.9) {
      return colorScheme.primary; // Close to complete - show primary color
    } else {
      return colorScheme.primary.withValues(
        alpha: .8,
      ); // Default progress color
    }
  }

  /// Toggles between collapsed and expanded items list
  void _toggleItemsList() {
    setState(() {
      _isItemsListCollapsed = !_isItemsListCollapsed;
      HapticFeedback.selectionClick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final billData = Provider.of<BillData>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors for visual consistency
    final itemBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.white;

    final itemShadowColor =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: .15)
            : Colors.black.withValues(alpha: .05);

    final progressBgColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: .3)
            : Colors.grey.withValues(alpha: .1);

    // Enable/disable UI based on subtotal presence
    final isSubtotalSet = billData.subtotal > 0;

    // Help text based on subtotal status
    final itemDescription =
        isSubtotalSet
            ? 'Add items that add to your subtotal'
            : 'Please enter a subtotal before adding items';

    final itemIcon = isSubtotalSet ? Icons.restaurant_menu : Icons.info_outline;

    // Control visibility of expand/collapse toggle
    final shouldShowCollapseControl =
        billData.items.length > _maxVisibleItemsWhenCollapsed;

    // Calculate which items to display based on collapsed state
    final visibleItems =
        _isItemsListCollapsed && shouldShowCollapseControl
            ? billData.items.take(_maxVisibleItemsWhenCollapsed).toList()
            : billData.items;

    return SectionCard(
      title: 'Add Items',
      subTitle: itemDescription,
      icon: itemIcon,
      children: [
        // Item name field
        TextFormField(
          controller: billData.itemNameController,
          decoration: AppInputDecoration.buildInputDecoration(
            context: context,
            labelText: 'Item name',
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

        // Item price field with add button
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
                onPressed: isSubtotalSet ? () => _addItem(billData) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSubtotalSet
                          ? colorScheme.primary
                          : Colors.grey.withValues(alpha: .3),
                  foregroundColor:
                      brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: .9)
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

        const SizedBox(height: 20),

        // Progress indicator showing items total vs subtotal
        if (billData.items.isNotEmpty && billData.subtotal > 0) ...[
          Row(
            children: [
              // Animated progress text with gradient color
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
                        ).withValues(alpha: .8),
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
                  color: colorScheme.onSurface.withValues(alpha: .8),
                ),
              ),
              const Spacer(),
              // Percentage pill with dynamic color
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getProgressColor(
                    context,
                    billData.animatedItemsTotal,
                    billData.subtotal,
                  ).withValues(alpha: .1),
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

          // Animated progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: progressBgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate progress percentage (capped at 100%)
                final progressPercentage =
                    billData.subtotal > 0
                        ? (billData.animatedItemsTotal / billData.subtotal)
                            .clamp(0.0, 1.0)
                        : 0.0;

                return Stack(
                  children: [
                    // Animated progress fill with gradient and shadow
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
                            ).withValues(alpha: .8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getProgressColor(
                              context,
                              billData.animatedItemsTotal,
                              billData.subtotal,
                            ).withValues(alpha: .3),
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

          // Items list section
          if (billData.items.isNotEmpty) ...[
            const SizedBox(height: 20),

            // Header with items count and clear all button
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
                if (shouldShowCollapseControl) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${billData.items.length})',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),

                // Clear all button - only show if multiple items exist
                if (billData.items.length > 1)
                  TextButton.icon(
                    onPressed: () {
                      // Confirmation dialog for clearing all items
                      AppDialogs.showConfirmationDialog(
                        context: context,
                        title: 'Clear All Items?',
                        message: 'Are you sure you want to remove all items?',
                        confirmText: 'Clear All',
                        isDestructive: true,
                      ).then((confirmed) {
                        if (confirmed == true) {
                          // Clear all items
                          for (int i = billData.items.length - 1; i >= 0; i--) {
                            billData.removeItem(i);
                          }
                          _updateAnimation(billData);
                          HapticFeedback.mediumImpact();
                        }
                      });
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

            // Expand/collapse control button
            if (shouldShowCollapseControl) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _toggleItemsList,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: .2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: .1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isItemsListCollapsed
                            ? 'Show All ${billData.items.length} Items'
                            : 'Collapse List',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isItemsListCollapsed
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Items list with card-style design for each item
            ...List.generate(visibleItems.length, (index) {
              final item = visibleItems[index];
              final originalIndex = billData.items.indexOf(item);

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
                        // Price pill with theme-colored background
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: .1),
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
                        // Delete button with ripple effect
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _removeItem(billData, originalIndex),
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

            // Add "+X more items" indicator when list is in collapsed state
            if (_isItemsListCollapsed && shouldShowCollapseControl) ...[
              const SizedBox(height: 8),
              // Calculate remaining items count
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outline.withValues(alpha: .15),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: colorScheme.primary.withValues(alpha: .1),
                    highlightColor: colorScheme.primary.withValues(alpha: .05),
                    onTap: () {
                      _toggleItemsList();
                      // Subtle haptic feedback for microinteraction
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: .05),
                            colorScheme.primary.withValues(alpha: .1),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+ ${billData.items.length - _maxVisibleItemsWhenCollapsed} more',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Keep the existing "Show Less" button for expanded view
            if (!_isItemsListCollapsed &&
                shouldShowCollapseControl &&
                visibleItems.length >= 4) ...[
              const SizedBox(height: 8),
              // AnimatedContainer for subtle entrance animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outline.withValues(alpha: .15),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: colorScheme.primary.withValues(alpha: .1),
                    highlightColor: colorScheme.primary.withValues(alpha: .05),
                    onTap: () {
                      _toggleItemsList();
                      // Subtle haptic feedback for microinteraction
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: .05),
                            colorScheme.primary.withValues(alpha: .1),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_double_arrow_up,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Show Less',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }
}
