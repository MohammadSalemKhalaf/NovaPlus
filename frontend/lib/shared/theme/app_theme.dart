import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.isDark,
    required this.background,
    required this.backgroundSoft,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceGlass,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.onBackground,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.success,
    required this.warning,
    required this.error,
  });

  final bool isDark;
  final Color background;
  final Color backgroundSoft;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceGlass;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color onBackground;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color success;
  final Color warning;
  final Color error;

  @override
  AppPalette copyWith({
    bool? isDark,
    Color? background,
    Color? backgroundSoft,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceGlass,
    Color? border,
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? onBackground,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppPalette(
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      backgroundSoft: backgroundSoft ?? this.backgroundSoft,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      onBackground: onBackground ?? this.onBackground,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }

    return AppPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t) ?? background,
      backgroundSoft: Color.lerp(backgroundSoft, other.backgroundSoft, t) ?? backgroundSoft,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t) ?? surfaceGlass,
      border: Color.lerp(border, other.border, t) ?? border,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onBackground: Color.lerp(onBackground, other.onBackground, t) ?? onBackground,
      onSurface: Color.lerp(onSurface, other.onSurface, t) ?? onSurface,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t) ?? onSurfaceMuted,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const palette = AppPalette(
      isDark: false,
      background: Color(0xFFF5F7FF),
      backgroundSoft: Color(0xFFEFF2FF),
      surface: Color(0xFFFFFFFF),
      surfaceElevated: Color(0xFFF9FAFF),
      surfaceGlass: Color(0xEEF3F6FF),
      border: Color(0xFFDDE3F3),
      primary: Color(0xFF5B4BFF),
      secondary: Color(0xFF007AFF),
      accent: Color(0xFF00B6C9),
      onBackground: Color(0xFF0F1630),
      onSurface: Color(0xFF1A2240),
      onSurfaceMuted: Color(0xFF5D6B93),
      success: Color(0xFF16A34A),
      warning: Color(0xFFEAB308),
      error: Color(0xFFDC2626),
    );

    final scheme = ColorScheme.light(
      primary: palette.primary,
      secondary: palette.secondary,
      surface: palette.surface,
      error: palette.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: palette.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      extensions: const <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.onBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.onBackground,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: palette.primary, size: 24);
          }
          return IconThemeData(color: palette.onSurfaceMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: palette.primary, fontWeight: FontWeight.w700);
          }
          return TextStyle(color: palette.onSurfaceMuted, fontWeight: FontWeight.w600);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceElevated,
        hintStyle: TextStyle(color: palette.onSurfaceMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const palette = AppPalette(
      isDark: true,
      background: Color(0xFF070A19),
      backgroundSoft: Color(0xFF0E1230),
      surface: Color(0xFF121733),
      surfaceElevated: Color(0xFF171E3E),
      surfaceGlass: Color(0xCC171E3E),
      border: Color(0xFF2A3366),
      primary: Color(0xFF6E63FF),
      secondary: Color(0xFF3AA8FF),
      accent: Color(0xFF21D4C5),
      onBackground: Color(0xFFF6F8FF),
      onSurface: Color(0xFFF2F5FF),
      onSurfaceMuted: Color(0xFFADB5DA),
      success: Color(0xFF22C55E),
      warning: Color(0xFFFBBF24),
      error: Color(0xFFF87171),
    );

    final scheme = ColorScheme.dark(
      primary: palette.primary,
      secondary: palette.secondary,
      surface: palette.surface,
      error: palette.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: palette.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      extensions: const <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.onBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.onBackground,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primary.withValues(alpha: 0.22),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: palette.primary, size: 24);
          }
          return IconThemeData(color: palette.onSurfaceMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: palette.primary, fontWeight: FontWeight.w700);
          }
          return TextStyle(color: palette.onSurfaceMuted, fontWeight: FontWeight.w600);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceElevated,
        hintStyle: TextStyle(color: palette.onSurfaceMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
      ),
    );
  }

  static AppPalette palette(BuildContext context) {
    return Theme.of(context).extension<AppPalette>()!;
  }
}
