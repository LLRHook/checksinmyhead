import 'package:flutter/material.dart';

class AppInputDecoration {
  static InputDecoration buildInputDecoration({
    required BuildContext context,
    required String labelText,
    String? prefixText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final labelColor = colorScheme.onSurface.withOpacity(0.7);
    final fillColor =
        brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : Colors.grey.shade50;
    final borderColor =
        brightness == Brightness.dark
            ? colorScheme.outline
            : Colors.grey.shade200;

    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w500),
      prefixText: prefixText,
      prefixIcon:
          prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: labelColor)
              : null,
      hintText: hintText,
      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
      filled: true,
      fillColor: fillColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
