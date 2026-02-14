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

import 'package:flutter/material.dart';
import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/models/person.dart';

/// BillData - ChangeNotifier class that manages bill calculation state
///
/// Handles input controllers, calculations, and state management for
/// bill splitting functionality including subtotal, tax, tip, and itemized expenses.
///
/// Provides methods to:
/// - Calculate bill totals based on user inputs
/// - Manage bill items (add, remove, calculate totals)
/// - Control tip settings (percentage or custom amount)
///
/// Notifies listeners when bill data changes to update UI components.
class BillData extends ChangeNotifier {
  // Text input controllers
  final TextEditingController subtotalController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController customTipController = TextEditingController();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController itemPriceController = TextEditingController();

  // Tip settings
  double tipPercentage = 18.0;
  bool useCustomTipAmount = false;

  // Bill calculation values
  double subtotal = 0.0;
  double tax = 0.0;
  double tipAmount = 0.0;
  double total = 0.0;

  // List of items to split
  List<BillItem> items = [];

  // Items total tracking
  double itemsTotal = 0.0;
  double animatedItemsTotal = 0.0;

  // Birthday person tracking
  Person? _birthdayPerson;
  Person? get birthdayPerson => _birthdayPerson;
  set birthdayPerson(Person? person) {
    _birthdayPerson = person;
    notifyListeners();
  }

  BillData() {
    // Add listeners to controllers for real-time calculation updates
    subtotalController.addListener(calculateBill);
    taxController.addListener(calculateBill);
    customTipController.addListener(calculateBill);
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    subtotalController.dispose();
    taxController.dispose();
    itemNameController.dispose();
    itemPriceController.dispose();
    customTipController.dispose();
    super.dispose();
  }

  /// Calculates bill totals based on current input values
  void calculateBill() {
    // Parse subtotal with error handling
    try {
      subtotal = double.tryParse(subtotalController.text) ?? 0.0;
    } catch (_) {
      subtotal = 0.0;
    }

    // Parse tax with error handling
    try {
      tax = double.tryParse(taxController.text) ?? 0.0;
    } catch (_) {
      tax = 0.0;
    }

    // Calculate tip based on mode (percentage or custom amount)
    if (useCustomTipAmount) {
      try {
        tipAmount = double.tryParse(customTipController.text) ?? 0.0;
      } catch (_) {
        tipAmount = 0.0;
      }
    } else {
      tipAmount = subtotal * (tipPercentage / 100);
    }

    // Calculate final total
    total = subtotal + tax + tipAmount;

    notifyListeners();
  }

  /// Recalculates the total of all items in the list
  void calculateItemsTotal() {
    double total = 0.0;
    for (var item in items) {
      total += item.price;
    }
    itemsTotal = total;
    notifyListeners();
  }

  /// Adds a new item to the list and updates totals
  void addItem(String name, double price) {
    items.add(BillItem(name: name, price: price, assignments: {}));
    calculateItemsTotal();
    notifyListeners();
  }

  /// Removes an item from the list and updates totals
  void removeItem(int index) {
    items.removeAt(index);
    calculateItemsTotal();
    notifyListeners();
  }

  /// Updates the animated total for UI transitions
  void updateAnimatedItemsTotal(double value) {
    animatedItemsTotal = value;
    notifyListeners();
  }

  /// Sets the tip percentage and recalculates the bill
  void setTipPercentage(double value) {
    tipPercentage = value;
    calculateBill();
  }

  /// Toggles between percentage-based and custom tip amounts
  void toggleCustomTipAmount(bool value) {
    useCustomTipAmount = value;
    calculateBill();
  }

  /// Updates the items list with new items that may have assignments
  void updateItems(List<BillItem> newItems) {
    // Clear current items
    items.clear();

    // Add all new items with their assignments
    items.addAll(newItems);

    // Recalculate totals
    calculateItemsTotal();
    notifyListeners();
  }
}
