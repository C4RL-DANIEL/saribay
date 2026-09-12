import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFF1B8A5A); // store green
  static const danger = Color(0xFFD64545);
  static const warning = Color(0xFFE8960C);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Responsive breakpoints: <600 phone, >=600 tablet.
bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;
