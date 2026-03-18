// Layered gradient background with decorative dots.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';

class DecorativeBackground extends StatelessWidget {
  const DecorativeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _DotField())),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.glowGradient),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DotField extends StatelessWidget {
  const _DotField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotFieldPainter(Theme.of(context).colorScheme.onPrimary.withOpacity(0.12)),
    );
  }
}

class _DotFieldPainter extends CustomPainter {
  _DotFieldPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final random = Random(42);
    const double radius = 1.6;

    for (var i = 0; i < 140; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotFieldPainter oldDelegate) => false;
}


