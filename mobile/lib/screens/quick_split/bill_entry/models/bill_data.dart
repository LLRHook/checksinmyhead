import 'package:checks_frontend/models/person.dart';
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

  // Keep these controllers but they won't be used actively
  final TextEditingController alcoholTaxController = TextEditingController();
  final TextEditingController customAlcoholTipController =
      TextEditingController();

  // Tip settings
  double tipPercentage = 18.0;
  bool useDifferentTipForAlcohol = false; // Keep but won't actively use
  double alcoholTipPercentage = 20.0; // Keep but won't actively use
  double alcoholAmount = 0.0; // Keep but won't actively use
  bool useCustomTipAmount = false;
  bool useCustomAlcoholTipAmount = false; // Keep but won't actively use

  // Bill calculation values
  double subtotal = 0.0;
  double tax = 0.0;
  double alcoholTax = 0.0; // Keep but won't actively use
  double tipAmount = 0.0;
  double alcoholTipAmount = 0.0; // Keep but won't actively use
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
    alcoholTaxController.addListener(calculateBill);
    customAlcoholTipController.addListener(calculateBill);
  }

  // Keep this but simplify its implementation
  void updateSharesWithAlcoholCharges(
    Map<Person, double> personShares,
    List<Person> participants,
    Person? birthdayPerson,
  ) {
    // Now this is just a pass-through method that doesn't do anything special
    // We keep it to avoid breaking existing code that calls it
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
    alcoholTaxController.dispose();
    customAlcoholTipController.dispose();
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

    // Calculate tip (simplify to just use one approach)
    if (useCustomTipAmount) {
      try {
        tipAmount = double.tryParse(customTipController.text) ?? 0.0;
      } catch (_) {
        tipAmount = 0.0;
      }
    } else {
      tipAmount = subtotal * (tipPercentage / 100);
    }

    // Set total without alcohol-specific calculations
    total = subtotal + tax + tipAmount;

    notifyListeners();
  }

  // Simplified method - no longer distributes anything
  void distributeAlcoholCosts() {
    // This is now a no-op method to avoid breaking existing code
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

  // Simplified method that doesn't calculate anything
  void calculateAlcoholAmount() {
    // This is now a no-op method to avoid breaking existing code
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
    notifyListeners();
  }

  // Keep this method but make it a no-op
  void toggleItemAlcohol(int index, bool isAlcohol) {
    // No-op method to avoid breaking existing code
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

  // Keep these methods but make them no-ops
  void toggleDifferentTipForAlcohol(bool value) {
    // No-op
  }

  void setAlcoholTipPercentage(double value) {
    // No-op
  }

  void toggleCustomAlcoholTipAmount(bool value) {
    // No-op
  }
}
