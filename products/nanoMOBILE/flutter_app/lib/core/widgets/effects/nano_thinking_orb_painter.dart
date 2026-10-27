// nano_thinking_orb_painter.dart — Pintor 2D Canvas de micro-esferas orbitales (Thinking Orbs).
// QUÉ HACE: Renderiza la constelación orbital punteada inspirada en thinking-orbs de Libraries.dev.
// CÓMO FUNCIONA: Calcula posiciones orbitales con fases trigonométricas desacopladas, halo difuso y puntos brillantes.
// POR QUÉ: Alto rendimiento a 60 FPS sin WebGL pesado ni shaders complejos (< 140 líneas).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_thinking_orb_theme.dart';

class NanoThinkingOrbPainter extends CustomPainter {
  final double animationValue;
  final NanoOrbTheme theme;

  const NanoThinkingOrbPainter({
    required this.animationValue,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.36;

    // Resplandor ambiental de fondo del orbe
    final ambientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.colors.first.withValues(alpha: 0.28 * theme.pulseIntensity),
          theme.colors.last.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, baseRadius * 1.3, ambientPaint);

    // Pintar los nodos / puntos orbitales (Dotted constellation de Libraries.dev)
    final dotCount = theme.dotCount;
    final speed = theme.speedMultiplier;

    for (int i = 0; i < dotCount; i++) {
      final angleStep = (2 * math.pi) / dotCount;
      final angle = angleStep * i + (animationValue * 2 * math.pi * speed);

      // Oscilación armónica radial
      final radiusPulse = math.sin(animationValue * 2 * math.pi * 2 + (i * 0.8));
      final currentRadius = baseRadius + (radiusPulse * 3.5 * theme.pulseIntensity);

      final x = center.dx + currentRadius * math.cos(angle);
      final y = center.dy + currentRadius * math.sin(angle);
      final dotPos = Offset(x, y);

      // Color cíclico de la paleta
      final colorIdx = i % theme.colors.length;
      final dotColor = theme.colors[colorIdx];

      // Halo del punto
      final haloPaint = Paint()
        ..color = dotColor.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(dotPos, 3.2, haloPaint);

      // Centro del punto nítido
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotPos, 1.8, dotPaint);
    }

    // Núcleo central pulsante
    final coreScale = 0.85 + 0.15 * math.sin(animationValue * 2 * math.pi * 3);
    final corePaint = Paint()
      ..color = theme.colors[0].withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(center, 3.5 * coreScale, corePaint);
  }

  @override
  bool shouldRepaint(covariant NanoThinkingOrbPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.theme.state != theme.state;
  }
}
