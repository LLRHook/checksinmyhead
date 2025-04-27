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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid price'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      if (price > 0) {
        // Check if adding this item would exceed the subtotal
        final newTotalItems = _itemsTotal + price;
        if (newTotalItems > _subtotal) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item total (\$${newTotalItems.toStringAsFixed(2)}) would exceed the subtotal (\$${_subtotal.toStringAsFixed(2)})'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        
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
          builder: (context) => AlertDialog(
            title: const Text('Items Don\'t Match Subtotal'),
            content: Text(
              'Your added items total \$${_itemsTotal.toStringAsFixed(2)}, but your subtotal is \$${_subtotal.toStringAsFixed(2)}. Do you want to continue anyway, or add more items?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Add More Items'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToItemAssignment();
                },
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        );
      } else {
        // All good, navigate to the next screen
        _navigateToItemAssignment();
      }
    } else {
      // Show error for missing subtotal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a subtotal amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  void _navigateToItemAssignment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ItemAssignmentScreen(
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Bill Details'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Participant avatars at the top - fixed to prevent overflow
            SizedBox(
              height: 60, // Reduced height
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.participants.length,
                itemBuilder: (context, index) {
                  final person = widget.participants[index];
                  return Container(
                    width: 55,
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: person.color,
                          radius: 18, // Smaller avatars
                          child: Text(
                            person.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            person.name,
                            style: Theme.of(context).textTheme.labelSmall, // Smaller text
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

            const SizedBox(height: 16), // Reduced spacing

            // Bill totals section
            Card(
              elevation: 0,
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Totals',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // Subtotal field
                    TextField(
                      controller: _subtotalController,
                      decoration: InputDecoration(
                        labelText: 'Subtotal',
                        prefixText: '\$',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_currencyFormatter],
                    ),

                    const SizedBox(height: 12),

                    // Tax field
                    TextField(
                      controller: _taxController,
                      decoration: InputDecoration(
                        labelText: 'Tax',
                        prefixText: '\$',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_currencyFormatter],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16), // Reduced spacing

            // Tip section
            Card(
              elevation: 0,
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and tip toggle
                    Row(
                      children: [
                        Text(
                          'Tip Options',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        // Simple toggle between percentage and custom amount
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap:
                                  () => setState(() {
                                    _useCustomTipAmount = false;
                                    _calculateBill();
                                  }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      !_useCustomTipAmount
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                  border: Border.all(
                                    color: colorScheme.primary,
                                  ),
                                ),
                                child: Text(
                                  '%',
                                  style: TextStyle(
                                    color:
                                        !_useCustomTipAmount
                                            ? Colors.white
                                            : colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap:
                                  () => setState(() {
                                    _useCustomTipAmount = true;
                                    _calculateBill();
                                  }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _useCustomTipAmount
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(16),
                                  ),
                                  border: Border.all(
                                    color: colorScheme.primary,
                                  ),
                                ),
                                child: Text(
                                  '\$',
                                  style: TextStyle(
                                    color:
                                        _useCustomTipAmount
                                            ? Colors.white
                                            : colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Custom tip amount field (visible when custom amount is selected)
                    if (_useCustomTipAmount)
                      TextField(
                        controller: _customTipController,
                        decoration: InputDecoration(
                          labelText: 'Tip Amount',
                          prefixText: '\$',
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_currencyFormatter],
                      ),

                    // Percentage tip options (visible when percentage is selected)
                    if (!_useCustomTipAmount) ...[
                      // Tip slider
                      Row(
                        children: [
                          Text('${_tipPercentage.toInt()}%'),
                          Expanded(
                            child: Slider(
                              value: _tipPercentage,
                              min: 0,
                              max: 50,
                              divisions: 50, // 1% increments
                              label: '${_tipPercentage.toInt()}%',
                              onChanged: (value) {
                                setState(() {
                                  _tipPercentage = value;
                                  _calculateBill();
                                });
                              },
                            ),
                          ),
                          // Removed direct typing option for percentage
                          Container(
                            width: 40,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_tipPercentage.toInt()}%',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Quick tip percentage buttons
                      Wrap(
                        spacing: 8,
                        children:
                            [15, 18, 20, 25, 30].map((percentage) {
                              return ActionChip(
                                label: Text('$percentage%'),
                                onPressed: () {
                                  setState(() {
                                    _tipPercentage = percentage.toDouble();
                                    _calculateBill();
                                  });
                                },
                                backgroundColor:
                                    _tipPercentage == percentage
                                        ? colorScheme.primary.withOpacity(0.2)
                                        : null,
                                side: BorderSide(
                                  color:
                                      _tipPercentage == percentage
                                          ? colorScheme.primary
                                          : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Separate alcohol tip toggle
                      SwitchListTile(
                        title: const Text('Different tip for alcohol?'),
                        subtitle: const Text(
                          'Useful for higher tips on drinks',
                        ),
                        value: _useDifferentTipForAlcohol,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            _useDifferentTipForAlcohol = value;
                            _calculateBill();
                          });
                        },
                      ),

                      // Show alcohol fields if separate tip is enabled
                      if (_useDifferentTipForAlcohol) ...[
                        const SizedBox(height: 12),

                        // Alcohol amount field
                        TextField(
                          controller: _alcoholController,
                          decoration: InputDecoration(
                            labelText: 'Alcohol portion of bill',
                            prefixText: '\$',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_currencyFormatter],
                        ),

                        const SizedBox(height: 12),

                        // Alcohol tip slider
                        Row(
                          children: [
                            Text('${_alcoholTipPercentage.toInt()}%'),
                            Expanded(
                              child: Slider(
                                value: _alcoholTipPercentage,
                                min: 0,
                                max: 50,
                                divisions: 50, // 1% increments
                                label: '${_alcoholTipPercentage.toInt()}%',
                                onChanged: (value) {
                                  setState(() {
                                    _alcoholTipPercentage = value;
                                    _calculateBill();
                                  });
                                },
                              ),
                            ),
                            // Removed direct typing option for percentage
                            Container(
                              width: 40,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_alcoholTipPercentage.toInt()}%',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16), // Reduced spacing

            // Item entry section
            Card(
              elevation: 0,
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Items (Optional)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adding items helps assign specific dishes to people',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Item name field
                    TextField(
                      controller: _itemNameController,
                      decoration: InputDecoration(
                        labelText: 'Item name',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Item price field with add button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _itemPriceController,
                            decoration: InputDecoration(
                              labelText: 'Item price',
                              prefixText: '\$',
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [_currencyFormatter],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Progress indicator showing items total vs subtotal
                    if (_items.isNotEmpty && _subtotal > 0) ...[
                      Row(
                        children: [
                          Text('Items: \$${_animatedItemsTotal.toStringAsFixed(2)}'),
                          const SizedBox(width: 4),
                          Text('of'),
                          const SizedBox(width: 4),
                          Text('\$${_subtotal.toStringAsFixed(2)}'),
                          const Spacer(),
                          Text('${(_animatedItemsTotal / _subtotal * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Smoothly animated progress indicator
                      LinearProgressIndicator(
                        value: _subtotal > 0 ? (_animatedItemsTotal / _subtotal).clamp(0.0, 1.0) : 0,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        color: _animatedItemsTotal > _subtotal 
                            ? colorScheme.error 
                            : _animatedItemsTotal == _subtotal 
                                ? colorScheme.primaryContainer
                                : colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 8,
                      ),
                      // Only show a small gap if there are items
                      const SizedBox(height: 12),
                    ],

                    // List of added items
                    if (_items.isNotEmpty) ...[
                      Text(
                        'Added Items',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: colorScheme.surfaceVariant.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(item.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => _removeItem(index),
                                    color: colorScheme.error,
                                  ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              dense: true,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16), // Reduced spacing

            // Bill summary
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withOpacity(0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Bill Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text('\$${_subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax:'),
                        Text('\$${_tax.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _useCustomTipAmount
                              ? 'Tip (Custom):'
                              : _useDifferentTipForAlcohol
                              ? 'Tip (Food/Alcohol):'
                              : 'Tip (${_tipPercentage.toInt()}%):',
                        ),
                        Text('\$${_tipAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16), // Reduced spacing

            // Continue button
            ElevatedButton(
              onPressed: _continueToItemAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Continue to Item Assignment",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}