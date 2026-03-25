// Theme configuration for light and dark modes.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_visual_tokens.dart';

class AppTheme {
  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final tokens = isDark ? AppVisualTokens.dark : AppVisualTokens.light;
    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFFF4F6FF),
            secondary: AppColors.darkAccent,
            surface: Color(0xFF121A2E),
            error: AppColors.rose,
          )
        : const ColorScheme.light(
            primary: AppColors.ink,
            secondary: AppColors.accent,
            surface: Color(0xFFF7FAFE),
            error: AppColors.rose,
          );
    final onSurface = tokens.textPrimary;
    final fieldFill =
        isDark ? const Color(0x66131F34) : const Color(0xE8FFFFFF);
    final borderColor = tokens.cardBorder;

    return ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS,
      visualDensity: VisualDensity.compact,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.night : AppColors.mist,
      textTheme:
          isDark ? AppTypography.darkTextTheme : AppTypography.lightTextTheme,
      extensions: <ThemeExtension<dynamic>>[
        tokens,
      ],
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
        primaryColor: tokens.accent,
        scaffoldBackgroundColor: isDark ? AppColors.night : AppColors.mist,
        barBackgroundColor: Colors.transparent,
        textTheme: CupertinoTextThemeData(
          primaryColor: tokens.accent,
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
        color: tokens.cardBackground,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(9)),
          borderSide: BorderSide(color: tokens.accent, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: tokens.accent,
          foregroundColor: isDark ? Colors.white : AppColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        backgroundColor: tokens.sheetBackground,
        contentTextStyle: TextStyle(color: tokens.textPrimary, fontSize: 13),
      ),
    );
  }
}
