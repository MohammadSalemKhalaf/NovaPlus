import 'package:flutter/material.dart';

class OwnerPalette {
  const OwnerPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceAlt,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.secondary,
    required this.onBackground,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceSoft,
    required this.success,
    required this.successSoft,
    required this.error,
    required this.errorSoft,
    required this.warning,
    required this.warningSoft,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceAlt;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color secondary;
  final Color onBackground;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color onSurfaceSoft;
  final Color success;
  final Color successSoft;
  final Color error;
  final Color errorSoft;
  final Color warning;
  final Color warningSoft;
}

class OwnerTheme {
  const OwnerTheme._();

  static ThemeData themeForMode(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = paletteForBrightness(brightness);

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: palette.primary,
            secondary: palette.secondary,
            surface: palette.surface,
            error: palette.error,
          )
        : ColorScheme.light(
            primary: palette.primary,
            secondary: palette.secondary,
            surface: palette.surface,
            error: palette.error,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.onBackground,
        elevation: 0,
        centerTitle: false,
      ),
      cardColor: palette.surface,
      dividerTheme: DividerThemeData(color: palette.border),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.onSurface),
        actionTextColor: palette.primary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.onSurfaceMuted,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        labelStyle: TextStyle(color: palette.onSurfaceMuted),
        hintStyle: TextStyle(color: palette.onSurfaceSoft),
        prefixIconColor: palette.primary,
        suffixIconColor: palette.onSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary),
        ),
      ),
    );
  }

  static ThemeData themeForModeName(String? modeName) {
    return themeForMode(modeName == 'light' ? Brightness.light : Brightness.dark);
  }

  static OwnerPalette palette(BuildContext context) {
    return paletteForBrightness(Theme.of(context).brightness);
  }

  static OwnerPalette paletteForBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      return const OwnerPalette(
        isDark: true,
        background: Color(0xFF07070F),
        surface: Color(0xFF12121A),
        surfaceElevated: Color(0xFF171725),
        surfaceAlt: Color(0xFF0E0E16),
        border: Color(0xFF2A2A35),
        primary: Color(0xFF7B61FF),
        primarySoft: Color(0xFF7C5CFF),
        secondary: Color(0xFF2E7BFF),
        onBackground: Colors.white,
        onSurface: Color(0xFFF0F0FF),
        onSurfaceMuted: Color(0xFF9A9AA8),
        onSurfaceSoft: Color(0xFF6B6B7A),
        success: Color(0xFF10B981),
        successSoft: Color(0xFF234D37),
        error: Color(0xFFEF4444),
        errorSoft: Color(0xFF4A2C2C),
        warning: Color(0xFFF59E0B),
        warningSoft: Color(0xFF3F3A1E),
      );
    }

    return const OwnerPalette(
      isDark: false,
      background: Color(0xFFF4F7FC),
      surface: Color(0xFFFFFFFF),
      surfaceElevated: Color(0xFFF0F4FF),
      surfaceAlt: Color(0xFFEAF0FF),
      border: Color(0xFFD7DDEA),
      primary: Color(0xFF6450F8),
      primarySoft: Color(0xFFE9E6FF),
      secondary: Color(0xFF2563EB),
      onBackground: Color(0xFF121826),
      onSurface: Color(0xFF172033),
      onSurfaceMuted: Color(0xFF5E6A82),
      onSurfaceSoft: Color(0xFF7A869D),
      success: Color(0xFF0F9D58),
      successSoft: Color(0xFFE2F4EA),
      error: Color(0xFFDC2626),
      errorSoft: Color(0xFFFDE8E8),
      warning: Color(0xFFD97706),
      warningSoft: Color(0xFFFDEDD0),
    );
  }
}