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

/// A single parsed item from a receipt (name + price).
class ParsedItem {
  final String name;
  final double price;
  final int quantity;

  const ParsedItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory ParsedItem.fromJson(Map<String, dynamic> json) {
    return ParsedItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
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
