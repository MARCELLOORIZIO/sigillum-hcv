import 'package:flutter/material.dart';

class SigillumTheme {
  static const Color ink = Color(0xFF100D18);
  static const Color deep = Color(0xFF181322);
  static const Color panel = Color(0xFF211A2D);
  static const Color panelSoft = Color(0xFF2A2238);
  static const Color ivory = Color(0xFFF8F6FB);
  static const Color muted = Color(0xFFB8B0C6);
  static const Color verified = Color(0xFF4DD58B);
  static const Color accent = Color(0xFF45D4D0);
  static const Color accentAlt = Color(0xFF8D7CFF);
  static const Color warning = Color(0xFFFFB85C);
  static const Color danger = Color(0xFFFF6B7A);

  static ThemeData userTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      secondary: accentAlt,
      surface: deep,
      error: danger,
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: ivory,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ivory,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        bodyLarge: TextStyle(fontSize: 17, height: 1.35),
        bodyMedium: TextStyle(fontSize: 16, height: 1.35),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        helperStyle: const TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0x665D526D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0x665D526D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(58),
          shape: rounded,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ivory,
          side: const BorderSide(color: Color(0xAA6E607D)),
          minimumSize: const Size.fromHeight(56),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          color: ivory,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(color: muted, fontSize: 16, height: 1.4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panel,
        selectedColor: accent,
        disabledColor: panelSoft,
        labelStyle: const TextStyle(color: ivory, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w800),
        side: const BorderSide(color: Color(0x665D526D)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelSoft,
        contentTextStyle: const TextStyle(color: ivory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
