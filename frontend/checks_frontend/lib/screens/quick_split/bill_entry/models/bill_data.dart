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

  // New controller for alcohol tax
  final TextEditingController alcoholTaxController = TextEditingController();

  // New controller for custom alcohol tip
  final TextEditingController customAlcoholTipController =
      TextEditingController();

  // Tip settings
  double tipPercentage = 18.0;
  bool useDifferentTipForAlcohol = false;
  double alcoholTipPercentage = 20.0;
  double alcoholAmount = 0.0;
  bool useCustomTipAmount = false;
  bool useCustomAlcoholTipAmount = false;

  // Bill calculation values
  double subtotal = 0.0;
  double tax = 0.0;
  double alcoholTax = 0.0; // New property
  double tipAmount = 0.0;
  double alcoholTipAmount =
      0.0; // New property to track alcohol tip for display
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
    customAlcoholTipController.addListener(
      calculateBill,
    ); // Add listener for custom alcohol tip
  }

  // Add this method to your BillData class
  void updateSharesWithAlcoholCharges(
    Map<Person, double> personShares,
    List<Person> participants,
    Person? birthdayPerson,
  ) {
    // Calculate alcohol charges per person based on item assignments
    for (var person in participants) {
      if (person == birthdayPerson) continue; // Skip birthday person

      double personAlcoholTax = 0.0;
      double personAlcoholTip = 0.0;

      // Loop through each item to find alcohol charges for this person
      for (var item in items) {
        if (item.isAlcohol && item.assignments.containsKey(person)) {
          double percentage = item.assignments[person]! / 100.0;

          // Add alcohol tax
          if (item.alcoholTaxPortion != null && item.alcoholTaxPortion! > 0) {
            personAlcoholTax += item.alcoholTaxPortion! * percentage;
          }

          // Add alcohol tip
          if (item.alcoholTipPortion != null && item.alcoholTipPortion! > 0) {
            personAlcoholTip += item.alcoholTipPortion! * percentage;
          }
        }
      }

      // Update the person's share with their alcohol charges
      if (personAlcoholTax > 0 || personAlcoholTip > 0) {
        personShares[person] =
            (personShares[person] ?? 0.0) + personAlcoholTax + personAlcoholTip;
      }
    }
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
    customAlcoholTipController
        .dispose(); // Dispose custom alcohol tip controller
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

      // Only reset alcoholTipAmount if not using different tip for alcohol
      if (!useDifferentTipForAlcohol) {
        alcoholTipAmount = 0.0;
      } else {
        // If using different tip for alcohol, keep calculating it
        if (useCustomAlcoholTipAmount) {
          try {
            alcoholTipAmount =
                double.tryParse(customAlcoholTipController.text) ?? 0.0;
          } catch (_) {
            alcoholTipAmount = 0.0;
          }
        } else {
          alcoholTipAmount = alcoholAmount * (alcoholTipPercentage / 100);
        }
      }
    } else {
      // Calculate food amount (subtotal minus alcohol)
      final foodAmount = subtotal - alcoholAmount;

      // Calculate tips based on percentages
      double foodTip = 0.0;
      double alcoholTip = 0.0;

      if (useDifferentTipForAlcohol) {
        if (useCustomAlcoholTipAmount) {
          // Use custom alcohol tip amounts
          try {
            alcoholTip =
                double.tryParse(customAlcoholTipController.text) ?? 0.0;
          } catch (_) {
            alcoholTip = 0.0;
          }
        } else {
          // Use percentage-based alcohol tip
          alcoholTip = alcoholAmount * (alcoholTipPercentage / 100);
        }

        foodTip = foodAmount * (tipPercentage / 100);
        tipAmount = foodTip;
        alcoholTipAmount = alcoholTip; // Store for display
      } else {
        tipAmount = subtotal * (tipPercentage / 100);
        alcoholTipAmount = 0.0;
      }
    }

    // Update total to include alcohol tax
    total = subtotal + tax + tipAmount + alcoholTax + alcoholTipAmount;

    // Distribute alcohol tax and tip to individual items
    distributeAlcoholCosts();

    notifyListeners();
  }

  // New method to distribute alcohol costs to individual items
  void distributeAlcoholCosts() {
    // Reset all alcohol costs first
    for (int i = 0; i < items.length; i++) {
      if (!items[i].isAlcohol) {
        items[i] = items[i].copyWith(
          alcoholTaxPortion: 0.0,
          alcoholTipPortion: 0.0,
        );
      }
    }

    // Only distribute if we have alcoholic items and costs
    if (alcoholAmount <= 0 || (alcoholTax <= 0 && alcoholTipAmount <= 0)) {
      return;
    }

    // Distribute proportionally to alcoholic items
    for (int i = 0; i < items.length; i++) {
      if (items[i].isAlcohol) {
        // Calculate this item's proportion of the total alcohol amount
        double proportion = items[i].price / alcoholAmount;

        // Calculate this item's share of alcohol tax and tip
        double itemAlcoholTax = alcoholTax * proportion;
        double itemAlcoholTip = alcoholTipAmount * proportion;

        // Update the item with its alcohol costs
        items[i] = items[i].copyWith(
          alcoholTaxPortion: itemAlcoholTax,
          alcoholTipPortion: itemAlcoholTip,
        );
      }
    }
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
  // Toggle alcohol status for an item
  void toggleItemAlcohol(int index, bool isAlcohol) {
    if (index >= 0 && index < items.length) {
      final item = items[index];
      items[index] = item.copyWith(
        isAlcohol: isAlcohol,
        // Clear alcohol costs if item is no longer alcoholic
        alcoholTaxPortion: isAlcohol ? item.alcoholTaxPortion : 0.0,
        alcoholTipPortion: isAlcohol ? item.alcoholTipPortion : 0.0,
      );

      calculateAlcoholAmount();
      calculateBill(); // This will redistribute alcohol costs
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

  // Toggle custom alcohol tip amount
  void toggleCustomAlcoholTipAmount(bool value) {
    useCustomAlcoholTipAmount = value;

    if (value) {
      customAlcoholTipController.text = "";
    }

    calculateBill();
  }
}
