// nano_border_beam_painter.dart — Pintor de haz perimetral GPU acelerado.
// QUÉ HACE: Dibuja un haz de luz viajero o halo perimetral sobre el contorno redondeado de una tarjeta.
// CÓMO FUNCIONA: Usa SweepGradient con rotación calculada sobre la trayectoria redondeada del RRect y desenfoque gausiano.
// POR QUÉ: Reproduce con precisión de 60fps el efecto Border Beam de Jakub Antalik sin dependencias externas (< 150 líneas).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_border_beam_theme.dart';

class NanoBorderBeamPainter extends CustomPainter {
  final double progress;
  final NanoBorderBeamMode mode;
  final NanoBorderBeamPalette palette;
  final double borderWidth;
  final double borderRadius;
  final double beamLengthFraction;
  final double strength;

  const NanoBorderBeamPainter({
    required this.progress,
    required this.mode,
    required this.palette,
    required this.borderWidth,
    required this.borderRadius,
    this.beamLengthFraction = 0.35,
    this.strength = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    if (mode == NanoBorderBeamMode.pulse) {
      _paintPulse(canvas, rrect);
    } else {
      _paintTravelingBeam(canvas, size, rrect);
    }
  }

  void _paintTravelingBeam(Canvas canvas, Size size, RRect rrect) {
    final angle = progress * 2 * math.pi;

    // Haz viajero: SweepGradient con ventana activa angular proporcional a beamLengthFraction
    final sweepAngle = beamLengthFraction * 2 * math.pi;
    final startAngle = angle - sweepAngle / 2;

    final colors = <Color>[];
    final stops = <double>[];

    // Gradiente con caída suave en los extremos
    colors.add(Colors.transparent);
    stops.add(0.0);

    for (int i = 0; i < palette.colors.length; i++) {
      final stop = 0.2 + (0.6 * (i / (palette.colors.length - 1)));
      colors.add(palette.colors[i].withValues(alpha: strength.clamp(0.0, 1.0)));
      stops.add(stop);
    }

    colors.add(Colors.transparent);
    stops.add(1.0);

    final sweepShader = SweepGradient(
      center: Alignment.center,
      colors: colors,
      stops: stops,
      transform: GradientRotation(startAngle),
    ).createShader(rrect.outerRect);

    // Capa 1: Resplandor difuso exterior (Glow)
    final glowPaint = Paint()
      ..shader = sweepShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 2.8
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, borderWidth * 3.2);

    canvas.drawRRect(rrect, glowPaint);

    // Capa 2: Núcleo nítido de luz de alta precisión
    final corePaint = Paint()
      ..shader = sweepShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, corePaint);
  }

  void _paintPulse(Canvas canvas, RRect rrect) {
    final breathe = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);
    final alpha = (0.2 + 0.6 * breathe) * strength;

    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * (1.0 + 0.5 * breathe)
      ..shader = LinearGradient(
        colors: palette.colors.map((c) => c.withValues(alpha: alpha.clamp(0.0, 1.0))).toList(),
      ).createShader(rrect.outerRect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * breathe);

    canvas.drawRRect(rrect, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant NanoBorderBeamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mode != mode ||
        oldDelegate.palette != palette ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strength != strength;
  }
}
