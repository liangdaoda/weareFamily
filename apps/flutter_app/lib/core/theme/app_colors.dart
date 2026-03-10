// App color palette and gradients.
import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF0F1C2E);
  static const Color night = Color(0xFF0A1320);
  static const Color mist = Color(0xFFE9EEF5);
  static const Color foam = Color(0xFFF8FAFD);
  static const Color accent = Color(0xFFFFB400);
  static const Color mint = Color(0xFF3AD6C2);
  static const Color rose = Color(0xFFFF6B6B);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF23395B), Color(0xFF1E6B8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

