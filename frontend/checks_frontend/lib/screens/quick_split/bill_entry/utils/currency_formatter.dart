import 'package:flutter/services.dart';

class CurrencyFormatter {
  // Custom formatter for currency input (allows numbers with up to 2 decimal places)
  static final TextInputFormatter currencyFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d+\.?\d{0,2}'),
  );

  // Format a double as currency string
  static String formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}