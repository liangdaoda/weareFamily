// Typography system using Google Fonts with CJK coverage.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme lightTextTheme = _buildTextTheme(
    const Color(0xFF0F1C2E),
    const Color(0xFF52606D),
  );

  static TextTheme darkTextTheme = _buildTextTheme(
    Colors.white,
    const Color(0xFFCAD5E2),
  );

  static TextTheme _buildTextTheme(Color primary, Color muted) {
    return TextTheme(
      displayLarge: GoogleFonts.notoSerifSc(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      displayMedium: GoogleFonts.notoSerifSc(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: GoogleFonts.notoSerifSc(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.notoSansSc(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.notoSansSc(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelLarge: GoogleFonts.notoSansSc(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }
}

