import 'package:flutter/material.dart';

/// Brand colours. Orange is for fills, never for words on cream.
abstract final class CatwalkColors {
  static const orange = Color(0xFFF69337);
  static const orangeSoft = Color(0xFFFFE3CC);
  static const teal = Color(0xFF1F7A7A);
  static const cream = Color(0xFFFFF6EA);
  static const ink = Color(0xFF1B2B30);
  static const inkMuted = Color(0xFF52626A);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFEBDCC9);
  static const error = Color(0xFFB3382C);
}

/// Warm cream, orange fills, teal accents, dark ink text.
ThemeData buildCatwalkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: CatwalkColors.orange,
    onPrimary: CatwalkColors.ink,
    primaryContainer: CatwalkColors.orangeSoft,
    onPrimaryContainer: CatwalkColors.ink,
    secondary: CatwalkColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD3ECEA),
    onSecondaryContainer: CatwalkColors.ink,
    tertiary: CatwalkColors.teal,
    onTertiary: Colors.white,
    error: CatwalkColors.error,
    onError: Colors.white,
    surface: CatwalkColors.cream,
    onSurface: CatwalkColors.ink,
    onSurfaceVariant: CatwalkColors.inkMuted,
    outline: Color(0xFF8A9499),
    outlineVariant: CatwalkColors.line,
    surfaceContainerHighest: CatwalkColors.orangeSoft,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: CatwalkColors.cream,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: CatwalkColors.cream,
      foregroundColor: CatwalkColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CatwalkColors.cream,
      indicatorColor: CatwalkColors.orangeSoft,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CatwalkColors.orange,
        foregroundColor: CatwalkColors.ink,
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CatwalkColors.ink,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: CatwalkColors.line),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: CatwalkColors.teal),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CatwalkColors.orange,
      linearTrackColor: CatwalkColors.orangeSoft,
      circularTrackColor: CatwalkColors.orangeSoft,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: CatwalkColors.teal, width: 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: CatwalkColors.ink,
      contentTextStyle: TextStyle(color: CatwalkColors.cream),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
  );
}
