import 'package:flutter/material.dart';

class SigillumTheme {
  // PancakeSwap light palette approved for the SIGILLUM consumer UI.
  static const Color ink = Color(0xFF280D5F);
  static const Color deep = Color(0xFFFAF9FA);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panelSoft = Color(0xFFEEEAF4);
  static const Color ivory = Color(0xFF280D5F);
  static const Color muted = Color(0xFF7A6EAA);
  static const Color verified = Color(0xFF31D0AA);
  static const Color accent = Color(0xFF1FC7D4);
  static const Color accentBright = Color(0xFF53DEE9);
  static const Color accentDark = Color(0xFF0098A1);
  static const Color accentAlt = Color(0xFF7645D9);
  static const Color warning = Color(0xFFFFB237);
  static const Color danger = Color(0xFFED4B9E);
  static const Color border = Color(0xFFE7E3EB);
  static const Color disabled = Color(0xFFE9EAEB);

  static ThemeData userTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: accentAlt,
      surface: panel,
      error: danger,
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: deep,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: panel,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: ink,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        bodyLarge: TextStyle(color: ink, fontSize: 17, height: 1.35),
        bodyMedium: TextStyle(color: ink, fontSize: 16, height: 1.35),
        labelLarge: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        helperStyle: const TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accentAlt, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: danger, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(62),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          shape: rounded,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(62),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          shape: rounded,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: accentAlt, width: 1.4),
          minimumSize: const Size.fromHeight(60),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(color: muted, fontSize: 16, height: 1.4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panelSoft,
        selectedColor: accent,
        disabledColor: disabled,
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w800),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelSoft,
        contentTextStyle: const TextStyle(color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: border),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentAlt,
        linearTrackColor: panelSoft,
      ),
    );
  }
}
