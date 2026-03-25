// Layered gradient background with decorative dots.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/theme/app_visual_tokens.dart';

class DecorativeBackground extends StatelessWidget {
  const DecorativeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Container(
      decoration: BoxDecoration(
        gradient: tokens.pageGradient,
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _DotField())),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(gradient: tokens.glowGradient),
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
      painter: _DotFieldPainter(context.visualTokens.dotColor),
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
    const double radius = 1.4;

    for (var i = 0; i < 96; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotFieldPainter oldDelegate) => false;
}
