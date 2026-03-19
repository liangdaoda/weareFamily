// Theme configuration for light and dark modes.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Colors.white,
            secondary: AppColors.accent,
            surface: AppColors.ink,
            error: AppColors.rose,
          )
        : const ColorScheme.light(
            primary: AppColors.ink,
            secondary: AppColors.accent,
            surface: AppColors.foam,
            error: AppColors.rose,
          );
    final onSurface = isDark ? Colors.white : AppColors.ink;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.84);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.08);

    return ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS,
      visualDensity: VisualDensity.compact,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.night : AppColors.mist,
      textTheme:
          isDark ? AppTypography.darkTextTheme : AppTypography.lightTextTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: isDark ? AppColors.night : AppColors.mist,
        barBackgroundColor: Colors.transparent,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.accent,
          textStyle: TextStyle(color: onSurface),
          navTitleTextStyle: TextStyle(
            color: onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF122235) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.72)),
        hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.55)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(9)),
          borderSide: BorderSide(color: AppColors.accent, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        backgroundColor:
            isDark ? const Color(0xFF14263A) : const Color(0xFF17324E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
