import 'package:flutter/material.dart';

class AppTheme {
  // Updated modern color palette
  static const Color _primaryColor = Color(0xFF627D98); // Slate blue-gray
  static const Color _secondaryColor = Color(0xFFD9B38C); // Muted warm tan
  static const Color _accentColor = Color(0xFF4C5B6B); // Deep steel blue
  static const Color _errorColor = Color(0xFFDC4C4C); // Softer modern red

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: _primaryColor,
      primaryContainer: Color(0xFFE3EAF0), // Soft background for slate
      onPrimaryContainer: _primaryColor,
      secondary: _secondaryColor,
      secondaryContainer: Color(0xFFFFF5ED),
      onSecondaryContainer: _secondaryColor.withValues(alpha: 0.85),
      tertiary: _accentColor,
      tertiaryContainer: Color(0xFFE6EAF1),
      onTertiaryContainer: _accentColor.withValues(alpha: 0.85),
      error: _errorColor,
      surface: Colors.white,
      onSurface: Color(0xFF2C2C2C),
      surfaceContainerHighest: Color(0xFFF1F3F5),
      onSurfaceVariant: Color(0xFF6B6B6B),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.25,
      ),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      bodyLarge: TextStyle(fontSize: 16, letterSpacing: 0.15, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, letterSpacing: 0.25, height: 1.5),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: const Color(0x26000000), // Using a standard shadow color
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _errorColor, width: 2),
      ),
      prefixIconColor: _primaryColor,
      suffixIconColor: const Color(0xFF9E9E9E),
      labelStyle: const TextStyle(color: Color(0xFF757575)),
      floatingLabelStyle: TextStyle(color: _primaryColor),
      errorStyle: TextStyle(color: _errorColor, fontSize: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        side: BorderSide(color: _primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.25,
        ),
      ),
    ),
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: _primaryColor,
      primaryContainer: Color(0xFF4C5E6A),
      onPrimaryContainer: Colors.white,
      secondary: _secondaryColor,
      secondaryContainer: Color(0xFFB48A63),
      onSecondaryContainer: Colors.white,
      tertiary: _accentColor,
      tertiaryContainer: Color(0xFF3B4B59),
      onTertiaryContainer: Colors.white,
      error: _errorColor,
      surface: Color(0xFF1C1C1C),
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF2A2A2A),
      onSurfaceVariant: Color(0xFFB0B0B0),
    ),

    // You can add dark cardTheme, inputDecorationTheme, etc. if needed.
  );
}
