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

import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A modal bottom sheet that displays parsed receipt data for user review.
///
/// Users can:
/// - Edit item names and prices
/// - Delete false-positive items
/// - Add missed items
/// - Edit subtotal, tax, and tip
/// - Apply the final result to BillData
class ReceiptReviewSheet extends StatefulWidget {
  final ParsedReceipt receipt;

  const ReceiptReviewSheet({super.key, required this.receipt});

  @override
  State<ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends State<ReceiptReviewSheet> {
  late List<_EditableItem> _items;
  late TextEditingController _subtotalController;
  late TextEditingController _taxController;
  late TextEditingController _tipController;

  // For adding new items
  final _newNameController = TextEditingController();
  final _newPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Expand quantity > 1 items into individual line items so users see
    // exactly what will be added to the bill (no surprises after Apply).
    _items = [];
    for (final i in widget.receipt.items) {
      if (i.quantity > 1) {
        final perUnit =
            double.parse((i.price / i.quantity).toStringAsFixed(2));
        final lastUnit = double.parse(
            (i.price - perUnit * (i.quantity - 1)).toStringAsFixed(2));
        for (int q = 0; q < i.quantity - 1; q++) {
          _items.add(_EditableItem(
            nameController: TextEditingController(text: i.name),
            priceController: TextEditingController(
                text: perUnit.toStringAsFixed(2)),
          ));
        }
        _items.add(_EditableItem(
          nameController: TextEditingController(text: i.name),
          priceController: TextEditingController(
              text: lastUnit.toStringAsFixed(2)),
        ));
      } else {
        _items.add(_EditableItem(
          nameController: TextEditingController(text: i.name),
          priceController: TextEditingController(
              text: i.price.toStringAsFixed(2)),
        ));
      }
    }
    _subtotalController = TextEditingController(
      text: widget.receipt.subtotal?.toStringAsFixed(2) ?? '',
    );
    _taxController = TextEditingController(
      text: widget.receipt.tax?.toStringAsFixed(2) ?? '',
    );
    _tipController = TextEditingController(
      text: widget.receipt.tip?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.nameController.dispose();
      item.priceController.dispose();
    }
    _subtotalController.dispose();
    _taxController.dispose();
    _tipController.dispose();
    _newNameController.dispose();
    _newPriceController.dispose();
    super.dispose();
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].nameController.dispose();
      _items[index].priceController.dispose();
      _items.removeAt(index);
    });
    HapticFeedback.mediumImpact();
  }

  void _addItem() {
    final name = _newNameController.text.trim();
    final price = double.tryParse(_newPriceController.text.trim());
    if (name.isEmpty || price == null || price <= 0) return;

    setState(() {
      _items.add(_EditableItem(
        nameController: TextEditingController(text: name),
        priceController: TextEditingController(
            text: price.toStringAsFixed(2)),
      ));
    });
    _newNameController.clear();
    _newPriceController.clear();
    HapticFeedback.mediumImpact();
  }

  void _apply() {
    final items = <ParsedItem>[];
    for (final item in _items) {
      final name = item.nameController.text.trim();
      final price = double.tryParse(item.priceController.text.trim());
      if (name.isNotEmpty && price != null && price > 0) {
        items.add(ParsedItem(
            name: name, price: price, quantity: 1));
      }
    }

    final subtotal = double.tryParse(_subtotalController.text.trim());
    final tax = double.tryParse(_taxController.text.trim());
    final tip = double.tryParse(_tipController.text.trim());

    Navigator.pop(
      context,
      ParsedReceipt(
        vendor: widget.receipt.vendor,
        items: items,
        subtotal: subtotal,
        tax: (tax != null && tax > 0) ? tax : null,
        tip: (tip != null && tip > 0) ? tip : null,
        total: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final bgColor = brightness == Brightness.dark
        ? colorScheme.surface
        : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Review Scanned Receipt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Tap to edit, swipe to delete',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable content
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Items section
                  if (_items.isNotEmpty) ...[
                    _buildSectionLabel('Items (${_items.length})', colorScheme),
                    const SizedBox(height: 8),
                    ..._buildItemsList(colorScheme, brightness),
                    const SizedBox(height: 12),
                  ],

                  // Add item row
                  _buildAddItemRow(colorScheme, brightness),
                  const SizedBox(height: 20),

                  // Summary fields
                  _buildSectionLabel('Totals', colorScheme),
                  const SizedBox(height: 8),
                  _buildSummaryField('Subtotal', _subtotalController, colorScheme, brightness),
                  const SizedBox(height: 10),
                  _buildSummaryField('Tax', _taxController, colorScheme, brightness),
                  const SizedBox(height: 10),
                  _buildSummaryField('Tip', _tipController, colorScheme, brightness),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _items.isNotEmpty ? _apply : null,
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text(
                          'Apply to Bill',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme colorScheme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  List<Widget> _buildItemsList(ColorScheme colorScheme, Brightness brightness) {
    final itemBgColor = brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : Colors.grey.shade50;

    return List.generate(_items.length, (index) {
      final item = _items[index];
      return Dismissible(
        key: ValueKey(item),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_outline, color: colorScheme.error),
        ),
        onDismissed: (_) => _removeItem(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: itemBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: .15),
            ),
          ),
          child: Row(
            children: [
              // Item name
              Expanded(
                flex: 3,
                child: TextField(
                  controller: item.nameController,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              // Item price
              SizedBox(
                width: 80,
                child: TextField(
                  controller: item.priceController,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    prefixText: '\$',
                    prefixStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyFormatter.currencyFormatter],
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAddItemRow(ColorScheme colorScheme, Brightness brightness) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _newNameController,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Add missed item...',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: .6),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .2)),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _newPriceController,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '\$',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: .6),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .2)),
              ),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [CurrencyFormatter.currencyFormatter],
            textAlign: TextAlign.right,
            onSubmitted: (_) => _addItem(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 38,
          width: 38,
          child: IconButton.filled(
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryField(
    String label,
    TextEditingController controller,
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    final fillColor = brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : Colors.grey.shade50;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              prefixText: '\$',
              hintText: '0.00',
              isDense: true,
              filled: true,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: .15)),
              ),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [CurrencyFormatter.currencyFormatter],
          ),
        ),
      ],
    );
  }
}

class _EditableItem {
  final TextEditingController nameController;
  final TextEditingController priceController;

  _EditableItem({
    required this.nameController,
    required this.priceController,
  });
}
