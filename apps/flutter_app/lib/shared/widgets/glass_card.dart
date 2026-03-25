// Glassmorphism-style card for summaries.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/theme/app_visual_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isDark ? 12 : 8,
          sigmaY: isDark ? 12 : 8,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: tokens.cardBorder),
            boxShadow: [
              BoxShadow(
                color: tokens.cardShadow,
                blurRadius: isDark ? 18 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
