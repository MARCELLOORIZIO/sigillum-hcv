import 'package:flutter/material.dart';

class SigillumTheme {
  static const Color ink = Color(0xFF08110F);
  static const Color deep = Color(0xFF0E1D19);
  static const Color panel = Color(0xFF14251F);
  static const Color ivory = Color(0xFFF4F1EA);
  static const Color muted = Color(0xFFAAB7B1);
  static const Color verified = Color(0xFF55D68B);
  static const Color accent = Color(0xFF6FD6C9);
  static const Color warning = Color(0xFFFFB15C);
  static const Color danger = Color(0xFFFF6B6B);

  static ThemeData userTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      secondary: verified,
      surface: deep,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: ivory,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ivory,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ivory,
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ivory,
          side: const BorderSide(color: Color(0x667E9189)),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
