// App color palette and gradients.
import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF0F1C2E);
  static const Color night = Color(0xFF0A1020);
  static const Color mist = Color(0xFFF1F4FA);
  static const Color foam = Color(0xFFFBFCFE);

  // Light mode accent.
  static const Color accent = Color(0xFFFFB400);
  static const Color accentHover = Color(0xFFFFC13A);
  static const Color accentPressed = Color(0xFFE49C00);

  // Dark mode accent (locked by product decision).
  static const Color darkAccent = Color(0xFFA99AF3);
  static const Color darkAccentHover = Color(0xFFB6A9F5);
  static const Color darkAccentPressed = Color(0xFF9382E9);

  static const Color mint = Color(0xFF3AD6C2);
  static const Color rose = Color(0xFFFF6B6B);
  static const Color memberAvatarStart = Color(0xFFB8D7FF);
  static const Color memberAvatarEnd = Color(0xFF86C0FF);
  static const Color ageTierChild = Color(0xFF6CCBFF);
  static const Color ageTierAdult = Color(0xFF79E2AE);
  static const Color ageTierSenior = Color(0xFFFFC986);

  static const LinearGradient lightHeroGradient = LinearGradient(
    colors: [Color(0xFF95BDE8), Color(0xFFBBD8F6), Color(0xFFE8F0FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeroGradient = LinearGradient(
    colors: [Color(0xFF0B1220), Color(0xFF131B30), Color(0xFF1A1833)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightGlowGradient = LinearGradient(
    colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGlowGradient = LinearGradient(
    colors: [Color(0x22A99AF3), Color(0x00101010)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
