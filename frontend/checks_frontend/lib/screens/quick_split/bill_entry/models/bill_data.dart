import 'package:flutter/material.dart';
import '/models/bill_item.dart';

class BillData extends ChangeNotifier {
  // Existing controllers
  final TextEditingController subtotalController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController customTipController = TextEditingController();
  final TextEditingController alcoholController = TextEditingController();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController itemPriceController = TextEditingController();

  // New controller for alcohol tax
  final TextEditingController alcoholTaxController = TextEditingController();

  // Tip settings
  double tipPercentage = 18.0;
  bool useDifferentTipForAlcohol = false;
  double alcoholTipPercentage = 20.0;
  double alcoholAmount = 0.0;
  bool useCustomTipAmount = false;

  // Bill calculation values
  double subtotal = 0.0;
  double tax = 0.0;
  double alcoholTax = 0.0; // New property
  double tipAmount = 0.0;
  double total = 0.0;

  // List of items to split
  List<BillItem> items = [];

  // Items total
  double itemsTotal = 0.0;
  double animatedItemsTotal = 0.0;

  BillData() {
    // Add listeners to controllers
    subtotalController.addListener(calculateBill);
    taxController.addListener(calculateBill);
    alcoholController.addListener(calculateBill);
    customTipController.addListener(calculateBill);
    alcoholTaxController.addListener(
      calculateBill,
    ); // Add listener for alcohol tax
  }

  @override
  void dispose() {
    // Dispose controllers
    subtotalController.dispose();
    taxController.dispose();
    alcoholController.dispose();
    itemNameController.dispose();
    itemPriceController.dispose();
    customTipController.dispose();
    alcoholTaxController.dispose(); // Dispose new controller
    super.dispose();
  }

  void calculateBill() {
    // Safely parse input values with validation
    try {
      subtotal = double.tryParse(subtotalController.text) ?? 0.0;
    } catch (_) {
      subtotal = 0.0;
    }

    try {
      tax = double.tryParse(taxController.text) ?? 0.0;
    } catch (_) {
      tax = 0.0;
    }

    try {
      alcoholTax = double.tryParse(alcoholTaxController.text) ?? 0.0;
    } catch (_) {
      alcoholTax = 0.0;
    }

    // Calculate alcohol amount based on marked items
    calculateAlcoholAmount();

    if (useCustomTipAmount) {
      // Use the custom tip amount directly with validation
      try {
        tipAmount = double.tryParse(customTipController.text) ?? 0.0;
      } catch (_) {
        tipAmount = 0.0;
      }
    } else {
      // Calculate food amount (subtotal minus alcohol)
      final foodAmount = subtotal - alcoholAmount;

      // Calculate tips based on percentages
      double foodTip = 0.0;
      double alcoholTip = 0.0;

      if (useDifferentTipForAlcohol) {
        foodTip = foodAmount * (tipPercentage / 100);
        alcoholTip = alcoholAmount * (alcoholTipPercentage / 100);
        tipAmount = foodTip + alcoholTip;
      } else {
        tipAmount = subtotal * (tipPercentage / 100);
      }
    }

    // Update total to include alcohol tax
    total = subtotal + tax + tipAmount + alcoholTax;

    notifyListeners();
  }

  // Calculate the total of all items
  void calculateItemsTotal() {
    double total = 0.0;
    for (var item in items) {
      total += item.price;
    }
    itemsTotal = total;
    notifyListeners();
  }

  // Calculate alcohol amount based on marked items
  void calculateAlcoholAmount() {
    double amount = 0.0;
    for (var item in items) {
      if (item.isAlcohol) {
        amount += item.price;
      }
    }

    // Only update controller if value has changed significantly
    if ((amount - alcoholAmount).abs() > 0.01) {
      // Update the alcohol amount
      alcoholAmount = amount;

      // Update the controller text if it's not focused (to avoid cursor jumping)
      if (alcoholController.text != amount.toStringAsFixed(2)) {
        alcoholController.text = amount.toStringAsFixed(2);
      }
    }
  }

  // Add an item to the list
  void addItem(String name, double price) {
    items.add(BillItem(name: name, price: price, assignments: {}));
    calculateItemsTotal();
    notifyListeners();
  }

  // Remove an item from the list
  void removeItem(int index) {
    items.removeAt(index);
    calculateItemsTotal();
    calculateAlcoholAmount(); // Recalculate alcohol amount
    notifyListeners();
  }

  // Toggle alcohol status for an item
  void toggleItemAlcohol(int index, bool isAlcohol) {
    if (index >= 0 && index < items.length) {
      final item = items[index];
      items[index] = BillItem(
        name: item.name,
        price: item.price,
        assignments: item.assignments,
        isAlcohol: isAlcohol,
      );

      calculateAlcoholAmount();
      calculateBill();
      notifyListeners();
    }
  }

  // Update animated items total
  void updateAnimatedItemsTotal(double value) {
    animatedItemsTotal = value;
    notifyListeners();
  }

  // Set tip percentage
  void setTipPercentage(double value) {
    tipPercentage = value;
    calculateBill();
  }

  // Toggle custom tip amount
  void toggleCustomTipAmount(bool value) {
    useCustomTipAmount = value;
    calculateBill();
  }

  // Toggle different tip for alcohol
  void toggleDifferentTipForAlcohol(bool value) {
    useDifferentTipForAlcohol = value;
    calculateBill();
  }

  // Set alcohol tip percentage
  void setAlcoholTipPercentage(double value) {
    alcoholTipPercentage = value;
    calculateBill();
  }
}
