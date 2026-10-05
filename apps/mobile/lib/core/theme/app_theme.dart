import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF216B4B);
  static const secondaryColor = Color(0xFF8EAC76);
  static const errorColor = Color(0xFFBA6653);
  static const warningColor = Color(0xFFB79858);
  static const successColor = primaryColor;
  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);
  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: primaryColor, brightness: brightness,
      surface: dark ? const Color(0xFF1C2C24) : Colors.white);
    final border = dark ? const Color(0xFF344B3B) : const Color(0xFFE5EBDF);
    return ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme,
      primaryColor: primaryColor, scaffoldBackgroundColor: dark ? const Color(0xFF14231B) : const Color(0xFFF8F9F5),
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, centerTitle: false, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 19, fontWeight: FontWeight.w600)),
      cardTheme: CardThemeData(color: scheme.surface, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: scheme.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: scheme.primary, width: 1.5))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), side: BorderSide(color: border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: scheme.surface, indicatorColor: scheme.primaryContainer.withValues(alpha: .6), height: 72),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }
}
