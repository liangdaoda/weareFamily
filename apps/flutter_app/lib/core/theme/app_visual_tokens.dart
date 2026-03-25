import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class AppVisualTokens extends ThemeExtension<AppVisualTokens> {
  const AppVisualTokens({
    required this.pageGradient,
    required this.glowGradient,
    required this.dotColor,
    required this.cardBackground,
    required this.cardBorder,
    required this.cardShadow,
    required this.memberCardBg,
    required this.memberCardBorder,
    required this.memberCardShadow,
    required this.memberInnerBlockBg,
    required this.memberChipBg,
    required this.sheetBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.accentSoftBg,
    required this.accentBorder,
    required this.success,
    required this.warning,
    required this.danger,
    required this.chartPrimary,
    required this.chartReference,
    required this.chartGrid,
    required this.chartLabel,
  });

  final Gradient pageGradient;
  final Gradient glowGradient;
  final Color dotColor;
  final Color cardBackground;
  final Color cardBorder;
  final Color cardShadow;
  final Color memberCardBg;
  final Color memberCardBorder;
  final Color memberCardShadow;
  final Color memberInnerBlockBg;
  final Color memberChipBg;
  final Color sheetBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color accentSoftBg;
  final Color accentBorder;
  final Color success;
  final Color warning;
  final Color danger;
  final Color chartPrimary;
  final Color chartReference;
  final Color chartGrid;
  final Color chartLabel;

  static const AppVisualTokens light = AppVisualTokens(
    pageGradient: AppColors.lightHeroGradient,
    glowGradient: AppColors.lightGlowGradient,
    dotColor: Color(0x2B1A3555),
    cardBackground: Color(0xD8FFFFFF),
    cardBorder: Color(0x3D1E4068),
    cardShadow: Color(0x260E1A2B),
    memberCardBg: Color(0xFFFDFEFF),
    memberCardBorder: Color(0xFFD9E4F1),
    memberCardShadow: Color(0x150E1A2B),
    memberInnerBlockBg: Color(0xFFF2F6FB),
    memberChipBg: Color(0xFFF4F7FC),
    sheetBackground: Color(0xF4FFFFFF),
    textPrimary: AppColors.ink,
    textSecondary: Color(0xCC243A52),
    textTertiary: Color(0x9938506A),
    accent: AppColors.accent,
    accentHover: AppColors.accentHover,
    accentPressed: AppColors.accentPressed,
    accentSoftBg: Color(0x2EFFE2A5),
    accentBorder: Color(0x7AFFB400),
    success: AppColors.mint,
    warning: AppColors.accent,
    danger: AppColors.rose,
    chartPrimary: Color(0xFF1E5E9A),
    chartReference: Color(0x8F5B7595),
    chartGrid: Color(0x2E32506D),
    chartLabel: Color(0xCC2A415A),
  );

  static const AppVisualTokens dark = AppVisualTokens(
    pageGradient: AppColors.darkHeroGradient,
    glowGradient: AppColors.darkGlowGradient,
    dotColor: Color(0x2FFFFFFF),
    cardBackground: Color(0x8F101B2D),
    cardBorder: Color(0x3DA99AF3),
    cardShadow: Color(0x4A060913),
    memberCardBg: Color(0x8F101B2D),
    memberCardBorder: Color(0x3DA99AF3),
    memberCardShadow: Color(0x4A060913),
    memberInnerBlockBg: Color(0x66172038),
    memberChipBg: Color(0x332A3552),
    sheetBackground: Color(0xF2201634),
    textPrimary: Color(0xFFF4F6FF),
    textSecondary: Color(0xC9D7DBF3),
    textTertiary: Color(0x8FAFB4CC),
    accent: AppColors.darkAccent,
    accentHover: AppColors.darkAccentHover,
    accentPressed: AppColors.darkAccentPressed,
    accentSoftBg: Color(0x2EA99AF3),
    accentBorder: Color(0x7AA99AF3),
    success: AppColors.mint,
    warning: Color(0xFFFFC27C),
    danger: AppColors.rose,
    chartPrimary: AppColors.darkAccent,
    chartReference: Color(0x7AB8C0DE),
    chartGrid: Color(0x33CBD2EE),
    chartLabel: Color(0xBFD5D9EF),
  );

  @override
  ThemeExtension<AppVisualTokens> copyWith({
    Gradient? pageGradient,
    Gradient? glowGradient,
    Color? dotColor,
    Color? cardBackground,
    Color? cardBorder,
    Color? cardShadow,
    Color? memberCardBg,
    Color? memberCardBorder,
    Color? memberCardShadow,
    Color? memberInnerBlockBg,
    Color? memberChipBg,
    Color? sheetBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentHover,
    Color? accentPressed,
    Color? accentSoftBg,
    Color? accentBorder,
    Color? success,
    Color? warning,
    Color? danger,
    Color? chartPrimary,
    Color? chartReference,
    Color? chartGrid,
    Color? chartLabel,
  }) {
    return AppVisualTokens(
      pageGradient: pageGradient ?? this.pageGradient,
      glowGradient: glowGradient ?? this.glowGradient,
      dotColor: dotColor ?? this.dotColor,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      memberCardBg: memberCardBg ?? this.memberCardBg,
      memberCardBorder: memberCardBorder ?? this.memberCardBorder,
      memberCardShadow: memberCardShadow ?? this.memberCardShadow,
      memberInnerBlockBg: memberInnerBlockBg ?? this.memberInnerBlockBg,
      memberChipBg: memberChipBg ?? this.memberChipBg,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentPressed: accentPressed ?? this.accentPressed,
      accentSoftBg: accentSoftBg ?? this.accentSoftBg,
      accentBorder: accentBorder ?? this.accentBorder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      chartPrimary: chartPrimary ?? this.chartPrimary,
      chartReference: chartReference ?? this.chartReference,
      chartGrid: chartGrid ?? this.chartGrid,
      chartLabel: chartLabel ?? this.chartLabel,
    );
  }

  @override
  ThemeExtension<AppVisualTokens> lerp(
    covariant ThemeExtension<AppVisualTokens>? other,
    double t,
  ) {
    if (other is! AppVisualTokens) {
      return this;
    }

    return AppVisualTokens(
      pageGradient: t < 0.5 ? pageGradient : other.pageGradient,
      glowGradient: t < 0.5 ? glowGradient : other.glowGradient,
      dotColor: Color.lerp(dotColor, other.dotColor, t) ?? dotColor,
      cardBackground:
          Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t) ?? cardShadow,
      memberCardBg:
          Color.lerp(memberCardBg, other.memberCardBg, t) ?? memberCardBg,
      memberCardBorder:
          Color.lerp(memberCardBorder, other.memberCardBorder, t) ??
              memberCardBorder,
      memberCardShadow:
          Color.lerp(memberCardShadow, other.memberCardShadow, t) ??
              memberCardShadow,
      memberInnerBlockBg:
          Color.lerp(memberInnerBlockBg, other.memberInnerBlockBg, t) ??
              memberInnerBlockBg,
      memberChipBg:
          Color.lerp(memberChipBg, other.memberChipBg, t) ?? memberChipBg,
      sheetBackground: Color.lerp(sheetBackground, other.sheetBackground, t) ??
          sheetBackground,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentHover: Color.lerp(accentHover, other.accentHover, t) ?? accentHover,
      accentPressed:
          Color.lerp(accentPressed, other.accentPressed, t) ?? accentPressed,
      accentSoftBg:
          Color.lerp(accentSoftBg, other.accentSoftBg, t) ?? accentSoftBg,
      accentBorder:
          Color.lerp(accentBorder, other.accentBorder, t) ?? accentBorder,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      chartPrimary:
          Color.lerp(chartPrimary, other.chartPrimary, t) ?? chartPrimary,
      chartReference:
          Color.lerp(chartReference, other.chartReference, t) ?? chartReference,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t) ?? chartGrid,
      chartLabel: Color.lerp(chartLabel, other.chartLabel, t) ?? chartLabel,
    );
  }
}

extension AppVisualThemeX on BuildContext {
  AppVisualTokens get visualTokens =>
      Theme.of(this).extension<AppVisualTokens>()!;
}
