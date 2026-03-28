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

/// Normalized bounding box for a receipt line item (coordinates 0.0–1.0).
class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A single parsed item from a receipt (name + price).
class ParsedItem {
  final String name;
  final double price;
  final int quantity;
  final BoundingBox? boundingBox;

  const ParsedItem({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.boundingBox,
  });

  factory ParsedItem.fromJson(Map<String, dynamic> json) {
    return ParsedItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      boundingBox: json['bounding_box'] != null
          ? BoundingBox.fromJson(json['bounding_box'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Structured data extracted from a receipt image.
class ParsedReceipt {
  final String? vendor;
  final List<ParsedItem> items;
  final double? subtotal;
  final double? tax;
  final double? tip;
  final double? total;

  const ParsedReceipt({
    this.vendor,
    required this.items,
    this.subtotal,
    this.tax,
    this.tip,
    this.total,
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => ParsedItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ParsedReceipt(
      vendor: json['vendor'] as String?,
      items: itemsList,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      tip: (json['tip'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
    );
  }
}
