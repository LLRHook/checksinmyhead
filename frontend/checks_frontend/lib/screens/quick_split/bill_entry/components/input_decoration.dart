import 'package:flutter/material.dart';

class AppInputDecoration {
  static InputDecoration buildInputDecoration({
    required BuildContext context,
    required String labelText,
    String? prefixText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      prefixText: prefixText,
      prefixIcon:
          prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: Colors.grey.shade600)
              : null,
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}