import 'package:flutter/material.dart';

/// Central design tokens + ThemeData so every screen shares one look.
class AppTheme {
  const AppTheme._();

  static const seed = Color(0xFF0E7C7B);
  static const brandDark = Color(0xFF0A4F55);
  static const brandLight = Color(0xFF17A2A0);

  static const radius = 16.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b).copyWith(
      surface: dark ? const Color(0xFF141B1C) : Colors.white,
      outlineVariant: dark ? const Color(0xFF2B3638) : const Color(0xFFE3EAEA),
    );
    final bg = dark ? const Color(0xFF0D1314) : const Color(0xFFF4F7F7);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: b);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge:
            base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1B2425) : const Color(0xFFF1F5F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
