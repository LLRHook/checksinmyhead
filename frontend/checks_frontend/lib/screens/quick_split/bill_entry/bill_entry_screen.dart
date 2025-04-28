import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '/models/bill_item.dart';
import '../item_assignment/item_assignment_screen.dart';

class BillEntryScreen extends StatefulWidget {
  final List<Person> participants;

  const BillEntryScreen({super.key, required this.participants});

  @override
  State<BillEntryScreen> createState() => _BillEntryScreenState();
}

class _BillEntryScreenState extends State<BillEntryScreen>
    with SingleTickerProviderStateMixin {
  final _subtotalController = TextEditingController();
  final _taxController = TextEditingController();
  final _customTipController = TextEditingController();

  // Tip settings
  double _tipPercentage = 18.0;
  bool _useDifferentTipForAlcohol = false;
  double _alcoholTipPercentage = 20.0;
  double _alcoholAmount = 0.0;
  final _alcoholController = TextEditingController();

  // Animation controller for progress bar
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  // Tip mode (percentage or custom amount)
  bool _useCustomTipAmount = false;

  // Bill calculation values
  double _subtotal = 0.0;
  double _tax = 0.0;
  double _tipAmount = 0.0;
  double _total = 0.0;

  // List of items to split
  final List<BillItem> _items = [];
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();

  // Total of all items
  double _itemsTotal = 0.0;
  double _animatedItemsTotal = 0.0;

  // Custom formatter for currency input
  final _currencyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d+\.?\d{0,2}'),
  );

  @override
  void initState() {
    super.initState();
    _subtotalController.addListener(_calculateBill);
    _taxController.addListener(_calculateBill);
    _alcoholController.addListener(_calculateBill);
    _customTipController.addListener(_calculateBill);

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
      setState(() {
        _animatedItemsTotal = _progressAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _subtotalController.dispose();
    _taxController.dispose();
    _alcoholController.dispose();
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _customTipController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _calculateBill() {
    setState(() {
      // Safely parse input values with validation
      try {
        _subtotal = double.tryParse(_subtotalController.text) ?? 0.0;
      } catch (_) {
        _subtotal = 0.0;
      }

      try {
        _tax = double.tryParse(_taxController.text) ?? 0.0;
      } catch (_) {
        _tax = 0.0;
      }

      try {
        _alcoholAmount = double.tryParse(_alcoholController.text) ?? 0.0;
      } catch (_) {
        _alcoholAmount = 0.0;
      }

      if (_useCustomTipAmount) {
        // Use the custom tip amount directly with validation
        try {
          _tipAmount = double.tryParse(_customTipController.text) ?? 0.0;
        } catch (_) {
          _tipAmount = 0.0;
        }
      } else {
        // Calculate food amount (subtotal minus alcohol)
        final foodAmount = _subtotal - _alcoholAmount;

        // Calculate tips based on percentages
        double foodTip = 0.0;
        double alcoholTip = 0.0;

        if (_useDifferentTipForAlcohol) {
          foodTip = foodAmount * (_tipPercentage / 100);
          alcoholTip = _alcoholAmount * (_alcoholTipPercentage / 100);
          _tipAmount = foodTip + alcoholTip;
        } else {
          _tipAmount = _subtotal * (_tipPercentage / 100);
        }
      }

      _total = _subtotal + _tax + _tipAmount;

      // Calculate items total
      _calculateItemsTotal();
    });
  }

  // Calculate the total of all items
  void _calculateItemsTotal() {
    double total = 0.0;
    for (var item in _items) {
      total += item.price;
    }

    // Only animate if there's a significant change
    if ((total - _itemsTotal).abs() > 0.01) {
      // Update the animation with new values
      _progressAnimation = Tween<double>(
        begin: _itemsTotal,
        end: total,
      ).animate(
        CurvedAnimation(
          parent: _progressAnimationController,
          curve: Curves.easeInOut,
        ),
      );

      // Reset and start the animation
      _progressAnimationController.reset();
      _progressAnimationController.forward();

      _itemsTotal = total;
    }
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final priceText = _itemPriceController.text.trim();

    if (name.isNotEmpty && priceText.isNotEmpty) {
      double price = 0.0;
      try {
        price = double.parse(priceText);
      } catch (_) {
        // Show error for invalid number
        _showSnackBar('Please enter a valid price');
        return;
      }

      if (price > 0) {
        // Check if adding this item would exceed the subtotal
        final newTotalItems = _itemsTotal + price;
        if (newTotalItems > _subtotal) {
          // Show error message
          _showSnackBar(
            'Item total (\$${newTotalItems.toStringAsFixed(2)}) would exceed the subtotal (\$${_subtotal.toStringAsFixed(2)})',
          );
          return;
        }

        // Add item with haptic feedback
        HapticFeedback.mediumImpact();

        setState(() {
          _items.add(BillItem(name: name, price: price, assignments: {}));
          _itemNameController.clear();
          _itemPriceController.clear();
          _calculateItemsTotal();
        });
      }
    }
  }

  void _removeItem(int index) {
    // Provide haptic feedback for item removal
    HapticFeedback.mediumImpact();

    setState(() {
      _items.removeAt(index);
      _calculateItemsTotal();
    });
  }

  void _continueToItemAssignment() {
    if (_subtotal > 0) {
      // Check if items have been added and if they match the subtotal
      if (_items.isNotEmpty && _itemsTotal < _subtotal) {
        // Show warning dialog that items don't match subtotal
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Items Don\'t Match Subtotal'),
                content: Text(
                  'Your added items total \$${_itemsTotal.toStringAsFixed(2)}, but your subtotal is \$${_subtotal.toStringAsFixed(2)}. Do you want to continue anyway, or add more items?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Provide feedback
                      HapticFeedback.selectionClick();
                    },
                    child: const Text('Add More Items'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Provide feedback
                      HapticFeedback.mediumImpact();
                      _navigateToItemAssignment();
                    },
                    child: const Text('Continue Anyway'),
                  ),
                ],
              ),
        );
      } else {
        // Provide haptic feedback for continuing
        HapticFeedback.mediumImpact();

        // All good, navigate to the next screen
        _navigateToItemAssignment();
      }
    } else {
      // Show error for missing subtotal
      _showSnackBar('Please enter a subtotal amount');
    }
  }

  void _navigateToItemAssignment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ItemAssignmentScreen(
              participants: widget.participants,
              items: _items,
              subtotal: _subtotal,
              tax: _tax,
              tipAmount: _tipAmount,
              total: _total,
              tipPercentage: _tipPercentage,
              alcoholTipPercentage: _alcoholTipPercentage,
              useDifferentAlcoholTip: _useDifferentTipForAlcohol,
            ),
      ),
    );
  }

  // Show a premium styled snackbar with haptic feedback
  void _showSnackBar(String message) {
    // Provide haptic feedback for error
    HapticFeedback.vibrate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        width: MediaQuery.of(context).size.width * 0.9,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Get color for progress indicator
  Color _getProgressColor(BuildContext context, double value) {
    final colorScheme = Theme.of(context).colorScheme;

    // The 0.99 threshold accounts for floating point rounding errors
    if ((value / _subtotal) > 1.0) {
      return colorScheme.error;
    } else if ((value / _subtotal) >= 0.99) {
      return const Color(0xFF4CAF50); // Material Green
    } else {
      return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Bill Details'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Participant avatars with premium styling
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.participants.length,
                itemBuilder: (context, index) {
                  final person = widget.participants[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: person.color.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            backgroundColor: person.color,
                            radius: 18,
                            child: Text(
                              person.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 45,
                          child: Text(
                            person.name,
                            style: textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Bill totals section
            _buildSectionCard(
              context,
              title: 'Bill Total',
              icon: Icons.receipt_long,
              children: [
                // Subtotal field with premium styling
                TextFormField(
                  controller: _subtotalController,
                  decoration: _buildInputDecoration(
                    labelText: 'Subtotal',
                    prefixText: '\$',
                    hintText: '0.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_currencyFormatter],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),

                // Tax field with premium styling
                TextFormField(
                  controller: _taxController,
                  decoration: _buildInputDecoration(
                    labelText: 'Tax',
                    prefixText: '\$',
                    hintText: '0.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_currencyFormatter],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Tip section
            _buildSectionCard(
              context,
              title: 'Tip Options',
              icon: Icons.volunteer_activism,
              children: [
                // Title and tip toggle
                Row(
                  children: [
                    const Spacer(),
                    // Modern toggle between percentage and custom amount
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _useCustomTipAmount = false;
                                _calculateBill();
                              });
                              // Provide feedback
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    !_useCustomTipAmount
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Percentage',
                                style: TextStyle(
                                  color:
                                      !_useCustomTipAmount
                                          ? Colors.white
                                          : colorScheme.onSurfaceVariant,
                                  fontWeight:
                                      !_useCustomTipAmount
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _useCustomTipAmount = true;
                                _calculateBill();
                              });
                              // Provide feedback
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _useCustomTipAmount
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Custom',
                                style: TextStyle(
                                  color:
                                      _useCustomTipAmount
                                          ? Colors.white
                                          : colorScheme.onSurfaceVariant,
                                  fontWeight:
                                      _useCustomTipAmount
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Custom tip amount field (visible when custom amount is selected)
                if (_useCustomTipAmount)
                  TextFormField(
                    controller: _customTipController,
                    decoration: _buildInputDecoration(
                      labelText: 'Tip Amount',
                      prefixText: '\$',
                      hintText: '0.00',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_currencyFormatter],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                // Percentage tip options (visible when percentage is selected)
                if (!_useCustomTipAmount) ...[
                  // Tip percentage display with premium styling
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${_tipPercentage.toInt()}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: colorScheme.primary,
                              inactiveTrackColor: colorScheme.primary
                                  .withOpacity(0.2),
                              thumbColor: colorScheme.primary,
                              overlayColor: colorScheme.primary.withOpacity(
                                0.2,
                              ),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                                elevation: 2,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                            ),
                            child: Slider(
                              value: _tipPercentage,
                              min: 0,
                              max: 50,
                              divisions: 50, // 1% increments
                              onChanged: (value) {
                                setState(() {
                                  _tipPercentage = value;
                                  _calculateBill();
                                });
                                // Light feedback on drag
                                if (value.toInt() % 5 == 0) {
                                  HapticFeedback.selectionClick();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick tip percentage buttons with premium styling
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [15, 18, 20, 25, 30].map((percentage) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _tipPercentage = percentage.toDouble();
                                _calculateBill();
                              });
                              // Provide feedback
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _tipPercentage == percentage
                                        ? colorScheme.primary
                                        : colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      _tipPercentage == percentage
                                          ? colorScheme.primary
                                          : colorScheme.outline.withOpacity(
                                            0.5,
                                          ),
                                  width: 1.5,
                                ),
                                boxShadow:
                                    _tipPercentage == percentage
                                        ? [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                        : null,
                              ),
                              child: Text(
                                '$percentage%',
                                style: TextStyle(
                                  color:
                                      _tipPercentage == percentage
                                          ? Colors.white
                                          : colorScheme.onSurface,
                                  fontWeight:
                                      _tipPercentage == percentage
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Separate alcohol tip toggle
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text('Different tip for alcohol?'),
                      subtitle: const Text('Useful for higher tips on drinks'),
                      value: _useDifferentTipForAlcohol,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _useDifferentTipForAlcohol = value;
                          _calculateBill();
                        });
                        // Provide feedback
                        HapticFeedback.selectionClick();
                      },
                      activeColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.surfaceVariant,
                    ),
                  ),

                  // Show alcohol fields if separate tip is enabled
                  if (_useDifferentTipForAlcohol) ...[
                    const SizedBox(height: 16),

                    // Alcohol amount field
                    TextFormField(
                      controller: _alcoholController,
                      decoration: _buildInputDecoration(
                        labelText: 'Alcohol portion of bill',
                        prefixText: '\$',
                        hintText: '0.00',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_currencyFormatter],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Alcohol tip percentage display with premium styling
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: colorScheme.tertiary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${_alcoholTipPercentage.toInt()}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.tertiary,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: colorScheme.tertiary,
                                inactiveTrackColor: colorScheme.tertiary
                                    .withOpacity(0.2),
                                thumbColor: colorScheme.tertiary,
                                overlayColor: colorScheme.tertiary.withOpacity(
                                  0.2,
                                ),
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                  elevation: 2,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16,
                                ),
                              ),
                              child: Slider(
                                value: _alcoholTipPercentage,
                                min: 0,
                                max: 50,
                                divisions: 50, // 1% increments
                                onChanged: (value) {
                                  setState(() {
                                    _alcoholTipPercentage = value;
                                    _calculateBill();
                                  });
                                  // Light feedback on drag
                                  if (value.toInt() % 5 == 0) {
                                    HapticFeedback.selectionClick();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Item entry section
            _buildSectionCard(
              context,
              title: 'Add Items (Optional)',
              subTitle: 'Adding items helps assign specific dishes to people',
              icon: Icons.restaurant_menu,
              children: [
                // Item name field with premium styling
                TextFormField(
                  controller: _itemNameController,
                  decoration: _buildInputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g., Pizza, Pasta, Salad',
                    prefixIcon: Icons.fastfood,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 16),

                // Item price field with add button - premium styling
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemPriceController,
                        decoration: _buildInputDecoration(
                          labelText: 'Item price',
                          prefixText: '\$',
                          hintText: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_currencyFormatter],
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
                        onPressed: _addItem,
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
                if (_items.isNotEmpty && _subtotal > 0) ...[
                  Row(
                    children: [
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback:
                            (Rect bounds) => LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                _getProgressColor(context, _animatedItemsTotal),
                                _getProgressColor(
                                  context,
                                  _animatedItemsTotal,
                                ).withOpacity(0.8),
                              ],
                            ).createShader(bounds),
                        child: Text(
                          'Items: \$${_animatedItemsTotal.toStringAsFixed(2)}',
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
                        '\$${_subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const Spacer(),
                      // Animated percentage with premium styling
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getProgressColor(
                            context,
                            _animatedItemsTotal,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(_animatedItemsTotal / _subtotal * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _getProgressColor(
                              context,
                              _animatedItemsTotal,
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
                                  (_subtotal > 0
                                      ? (_animatedItemsTotal / _subtotal).clamp(
                                        0.0,
                                        1.0,
                                      )
                                      : 0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    _getProgressColor(
                                      context,
                                      _animatedItemsTotal,
                                    ),
                                    _getProgressColor(
                                      context,
                                      _animatedItemsTotal,
                                    ).withOpacity(0.8),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getProgressColor(
                                      context,
                                      _animatedItemsTotal,
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
                  if (_items.isNotEmpty) ...[
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

                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
                                      color: colorScheme.primary.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '\$${item.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                      overflow:
                                          TextOverflow.ellipsis, // Add this
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
                                    onTap: () => _removeItem(index),
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
            ),

            const SizedBox(height: 20),

            // Bill summary with premium styling
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.primaryContainer.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Premium title with icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.summarize,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bill Summary',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Premium summary rows
                  _buildSummaryRow(
                    label: 'Subtotal',
                    value: _subtotal,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 10),

                  _buildSummaryRow(
                    label: 'Tax',
                    value: _tax,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 10),

                  _buildSummaryRow(
                    label:
                        _useCustomTipAmount
                            ? 'Tip (Custom)'
                            : _useDifferentTipForAlcohol
                            ? 'Tip (Food/Alcohol)'
                            : 'Tip (${_tipPercentage.toInt()}%)',
                    value: _tipAmount,
                    colorScheme: colorScheme,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, thickness: 1),
                  ),

                  // Premium total row
                  // Replace the premium total row with this:
                  Row(
                    children: [
                      // Left side - the TOTAL label
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      // Spacer to push the price to the right
                      const Spacer(),
                      // Right side - the price in container with fixed width
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimaryContainer.withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Premium continue button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _continueToItemAssignment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: colorScheme.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Continue to Item Assignment",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward, size: 18),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Helper method to build consistent section cards
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    String? subTitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Optional subtitle
          if (subTitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                subTitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Section content
          ...children,
        ],
      ),
    );
  }

  // Helper method to build consistent summary rows
  Widget _buildSummaryRow({
    required String label,
    required double value,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        // Use Expanded instead of Flexible to force the label to take available space
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Use a fixed width SizedBox for the value to ensure consistency
        SizedBox(
          width:
              80, // Fixed width for the price that should be enough for any reasonable value
          child: Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
            textAlign:
                TextAlign.right, // Right align text within the fixed width
          ),
        ),
      ],
    );
  }

  // Helper method to build consistent input decorations
  InputDecoration _buildInputDecoration({
    required String labelText,
    String? prefixText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      prefixText: prefixText,
      prefixIcon:
          prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: Colors.grey.shade600)
              : null,
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
