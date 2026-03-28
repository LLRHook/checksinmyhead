// Billington: Privacy-first receipt splitting
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

import 'dart:io';

import 'package:checks_frontend/screens/quick_split/bill_entry/utils/currency_formatter.dart';
import 'package:checks_frontend/services/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen compare view: receipt photo (with bounding box overlays)
/// on top, editable parsed items list on the bottom. Replaces the old
/// ReceiptReviewSheet modal bottom sheet for a richer verification UX.
class ReceiptCompareScreen extends StatefulWidget {
  final ParsedReceipt receipt;
  final String imagePath;
  final Size? imageSize;

  const ReceiptCompareScreen({
    super.key,
    required this.receipt,
    required this.imagePath,
    this.imageSize,
  });

  @override
  State<ReceiptCompareScreen> createState() => _ReceiptCompareScreenState();
}

class _ReceiptCompareScreenState extends State<ReceiptCompareScreen>
    with TickerProviderStateMixin {
  // Editable items (same pattern as ReceiptReviewSheet)
  late List<_EditableItem> _items;
  late TextEditingController _subtotalController;
  late TextEditingController _taxController;
  late TextEditingController _tipController;
  final _newNameController = TextEditingController();
  final _newPriceController = TextEditingController();

  // Selection state for highlight linking
  int? _selectedItemIndex;

  // Draggable divider position (fraction for photo section)
  double _dividerPosition = 0.40;

  // Staggered bounding box animation
  late AnimationController _bboxAnimController;
  late List<Animation<double>> _bboxAnimations;

  // Entry animations
  late AnimationController _entryController;
  late Animation<Offset> _photoSlide;
  late Animation<Offset> _listSlide;

  // Scroll controller for list section
  final _listScrollController = ScrollController();

  // Resolved image dimensions (for bounding box coordinate mapping)
  Size? _imageSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _initItems();
    _initBboxAnimations();
    _initEntryAnimations();
    if (widget.imageSize != null) {
      _imageSize = widget.imageSize;
    } else {
      _resolveImageSize();
    }
  }

  void _initItems() {
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
            priceController:
                TextEditingController(text: perUnit.toStringAsFixed(2)),
            boundingBox: i.boundingBox,
          ));
        }
        _items.add(_EditableItem(
          nameController: TextEditingController(text: i.name),
          priceController:
              TextEditingController(text: lastUnit.toStringAsFixed(2)),
          boundingBox: i.boundingBox,
        ));
      } else {
        _items.add(_EditableItem(
          nameController: TextEditingController(text: i.name),
          priceController:
              TextEditingController(text: i.price.toStringAsFixed(2)),
          boundingBox: i.boundingBox,
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

  void _resolveImageSize() {
    final file = File(widget.imagePath);
    if (!file.existsSync()) return;

    final imageProvider = FileImage(file);
    _imageStreamListener = ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      }
    });
    _imageStream = imageProvider.resolve(const ImageConfiguration());
    _imageStream!.addListener(_imageStreamListener!);
  }

  /// Compute the actual rendered rect of an image with [BoxFit.contain]
  /// inside a container of [containerSize].
  Rect _containedImageRect(Size containerSize) {
    if (_imageSize == null) {
      return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
    }

    final imageAspect = _imageSize!.width / _imageSize!.height;
    final containerAspect = containerSize.width / containerSize.height;

    double renderWidth, renderHeight;
    if (imageAspect > containerAspect) {
      // Image is wider than container → letterbox top/bottom
      renderWidth = containerSize.width;
      renderHeight = containerSize.width / imageAspect;
    } else {
      // Image is taller than container → letterbox left/right
      renderHeight = containerSize.height;
      renderWidth = containerSize.height * imageAspect;
    }

    final offsetX = (containerSize.width - renderWidth) / 2;
    final offsetY = (containerSize.height - renderHeight) / 2;
    return Rect.fromLTWH(offsetX, offsetY, renderWidth, renderHeight);
  }

  void _initBboxAnimations() {
    final itemCount = _items.length;
    _bboxAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + itemCount * 60),
    );

    _bboxAnimations = List.generate(itemCount, (i) {
      final start = i / (itemCount + 1);
      final end = ((i + 1) / (itemCount + 1)).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _bboxAnimController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    // Start after entry animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _bboxAnimController.forward();
    });
  }

  void _initEntryAnimations() {
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _photoSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    _listSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryController.forward();
    });
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    for (final item in _items) {
      item.nameController.dispose();
      item.priceController.dispose();
    }
    _subtotalController.dispose();
    _taxController.dispose();
    _tipController.dispose();
    _newNameController.dispose();
    _newPriceController.dispose();
    _bboxAnimController.dispose();
    _entryController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _selectItem(int index) {
    setState(() {
      _selectedItemIndex = (_selectedItemIndex == index) ? null : index;
    });

    // Scroll the list to make the selected item visible
    if (_selectedItemIndex != null &&
        _selectedItemIndex! < _items.length &&
        _items[_selectedItemIndex!].key.currentContext != null) {
      Scrollable.ensureVisible(
        _items[_selectedItemIndex!].key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].nameController.dispose();
      _items[index].priceController.dispose();
      _items.removeAt(index);
      if (_selectedItemIndex == index) {
        _selectedItemIndex = null;
      } else if (_selectedItemIndex != null && _selectedItemIndex! > index) {
        _selectedItemIndex = _selectedItemIndex! - 1;
      }
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
        priceController:
            TextEditingController(text: price.toStringAsFixed(2)),
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
        items.add(ParsedItem(name: name, price: price, quantity: 1));
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

  double get _computedItemsTotal {
    double total = 0;
    for (final item in _items) {
      total += double.tryParse(item.priceController.text.trim()) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final bgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Compare Receipt',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          if (isWide) {
            return _buildSideBySideLayout(
                constraints, colorScheme, brightness, bottomInset);
          }
          return _buildStackedLayout(
              constraints, colorScheme, brightness, bottomInset);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Portrait: stacked layout with draggable divider
  // -------------------------------------------------------------------------

  Widget _buildStackedLayout(
    BoxConstraints constraints,
    ColorScheme colorScheme,
    Brightness brightness,
    double bottomInset,
  ) {
    final availableHeight = constraints.maxHeight;
    final photoHeight = availableHeight * _dividerPosition;
    final listHeight = availableHeight * (1.0 - _dividerPosition);

    return Column(
      children: [
        // Photo section
        SlideTransition(
          position: _photoSlide,
          child: SizedBox(
            height: photoHeight - 12,
            child: _buildPhotoSection(colorScheme, constraints),
          ),
        ),
        // Draggable divider
        GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _dividerPosition = (_dividerPosition +
                      details.delta.dy / availableHeight)
                  .clamp(0.25, 0.65);
            });
          },
          child: Container(
            height: 24,
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        // List section
        SlideTransition(
          position: _listSlide,
          child: SizedBox(
            height: listHeight - 12,
            child: _buildListSection(colorScheme, brightness, bottomInset),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Landscape / iPad: side-by-side layout
  // -------------------------------------------------------------------------

  Widget _buildSideBySideLayout(
    BoxConstraints constraints,
    ColorScheme colorScheme,
    Brightness brightness,
    double bottomInset,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 45,
          child: SlideTransition(
            position: _photoSlide,
            child: _buildPhotoSection(colorScheme, constraints),
          ),
        ),
        VerticalDivider(
          width: 1,
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
        Expanded(
          flex: 55,
          child: SlideTransition(
            position: _listSlide,
            child: _buildListSection(colorScheme, brightness, bottomInset),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Photo section with bounding box overlays
  // -------------------------------------------------------------------------

  Widget _buildPhotoSection(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: LayoutBuilder(
          builder: (context, photoConstraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Receipt image
                Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Bounding box overlays
                ..._buildBoundingBoxOverlays(
                  colorScheme,
                  photoConstraints,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBoundingBoxOverlays(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final containerSize =
        Size(constraints.maxWidth, constraints.maxHeight);
    final imageRect = _containedImageRect(containerSize);

    final overlays = <Widget>[];
    for (int i = 0; i < _items.length; i++) {
      final bbox = _items[i].boundingBox;
      if (bbox == null) continue;

      final isSelected = _selectedItemIndex == i;
      final color =
          isSelected ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.5);

      overlays.add(
        Positioned(
          left: imageRect.left + bbox.x * imageRect.width,
          top: imageRect.top + bbox.y * imageRect.height,
          width: bbox.width * imageRect.width,
          height: bbox.height * imageRect.height,
          child: FadeTransition(
            opacity: i < _bboxAnimations.length
                ? _bboxAnimations[i]
                : const AlwaysStoppedAnimation(1.0),
            child: GestureDetector(
              onTap: () => _selectItem(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: color,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: color.withValues(alpha: isSelected ? 0.2 : 0.08),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return overlays;
  }

  // -------------------------------------------------------------------------
  // List section: editable items + totals + action buttons
  // -------------------------------------------------------------------------

  Widget _buildListSection(
    ColorScheme colorScheme,
    Brightness brightness,
    double bottomInset,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _listScrollController,
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 8),
            children: [
              // Items count + computed total
              _buildItemsHeader(colorScheme),
              const SizedBox(height: 8),
              // Item rows
              ...List.generate(_items.length, (i) {
                return _buildItemRow(i, colorScheme, brightness);
              }),
              const SizedBox(height: 8),
              // Add item row
              _buildAddItemRow(colorScheme),
              const SizedBox(height: 20),
              // Summary fields
              _buildSectionLabel('Totals', colorScheme),
              const SizedBox(height: 8),
              _buildSummaryField(
                  'Subtotal', _subtotalController, colorScheme, brightness),
              const SizedBox(height: 10),
              _buildSummaryField(
                  'Tax', _taxController, colorScheme, brightness),
              const SizedBox(height: 10),
              _buildSummaryField(
                  'Tip', _tipController, colorScheme, brightness),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // Action buttons
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 8 : 16),
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
    );
  }

  Widget _buildItemsHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        _buildSectionLabel('Items (${_items.length})', colorScheme),
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            '\$${_computedItemsTotal.toStringAsFixed(2)}',
            key: ValueKey(_computedItemsTotal.toStringAsFixed(2)),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(
      int index, ColorScheme colorScheme, Brightness brightness) {
    final item = _items[index];
    final isSelected = _selectedItemIndex == index;
    final hasBbox = item.boundingBox != null;

    final itemBgColor = brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : Colors.grey.shade50;

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
      child: GestureDetector(
        onTap: hasBbox ? () => _selectItem(index) : null,
        child: AnimatedContainer(
          key: item.key,
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: itemBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: .15),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Selection indicator
              if (hasBbox)
                Container(
                  width: 4,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
                  onChanged: (_) => setState(() {}),
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
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddItemRow(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _newNameController,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
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
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
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
              foregroundColor: Colors.white,
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
  BoundingBox? boundingBox;
  final GlobalKey key;

  _EditableItem({
    required this.nameController,
    required this.priceController,
    this.boundingBox,
  }) : key = GlobalKey();
}
