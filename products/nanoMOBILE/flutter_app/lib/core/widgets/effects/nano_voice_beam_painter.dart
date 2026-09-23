// nano_voice_beam_painter.dart — Pintor CustomPainter GPU-accelerated para VoiceBeam.
// QUÉ HACE: Dibuja el halo de audio y el cometa oscilante de pensamiento en el borde inferior.
// CÓMO FUNCIONA: En modo escucha calcula lóbulos radiales proporcionales al RMS; en modo proceso anima un haz senoidal.
// POR QUÉ: Rendimiento nativo a 60 FPS con aislamiento en Canvas y cero dependencias externas (< 200 líneas).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_voice_beam_theme.dart';

class NanoVoiceBeamPainter extends CustomPainter {
  const NanoVoiceBeamPainter({
    required this.phase,
    required this.audioLevel,
    required this.isListening,
    required this.isProcessing,
    required this.palette,
    required this.physics,
    this.borderRadius = 22.0,
  });

  final double phase;
  final double audioLevel;
  final bool isListening;
  final bool isProcessing;
  final NanoVoiceBeamPalette palette;
  final NanoVoiceBeamPhysics physics;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isListening && !isProcessing) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Modo 1: Escucha activa — Halo orgánico reactivo al volumen del micrófono
    if (isListening) {
      _paintListeningGlow(canvas, size, rrect);
    }

    // Modo 2: Pensamiento / Generación — Haz viajero oscilante (Libraries.dev sweeper)
    if (isProcessing) {
      _paintProcessingBeam(canvas, size, rrect);
    }
  }

  void _paintListeningGlow(Canvas canvas, Size size, RRect rrect) {
    final effectiveVolume = ((audioLevel - physics.noiseFloor) * physics.gain)
        .clamp(0.0, 1.0);
    if (effectiveVolume <= 0.01) return;

    final bloomHeight = 4.0 + effectiveVolume * physics.maxBloomHeight;
    final bottomY = size.height;

    // Dibujar 3 lóbulos de gradiente multicapa en la base
    final lobes = [0.25, 0.50, 0.75];
    for (var i = 0; i < lobes.length; i++) {
      final lobeX = size.width * lobes[i];
      final lobePhase = (phase * 2 * math.pi + i * 1.2);
      final oscillation = 0.85 + 0.15 * math.sin(lobePhase);
      final radius = (size.width * 0.32 * oscillation).clamp(20.0, 180.0);

      final colorIndex = (i * 2) % palette.colors.length;
      final lobeColor = palette.colors[colorIndex].withValues(
        alpha: (0.35 * effectiveVolume * oscillation).clamp(0.0, 0.85),
      );

      final paint = Paint()
        ..shader = RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.0,
          colors: [lobeColor, lobeColor.withValues(alpha: 0.0)],
        ).createShader(
          Rect.fromCircle(center: Offset(lobeX, bottomY), radius: radius),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bloomHeight * 0.4);

      canvas.drawCircle(Offset(lobeX, bottomY), radius, paint);
    }

    // Borde inferior lumínico de acento
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: palette.colors.map((c) => c.withValues(alpha: effectiveVolume)).toList(),
      ).createShader(Rect.fromLTWH(0, bottomY - 2, size.width, 2))
      ..strokeWidth = physics.beamThickness
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(borderRadius, bottomY)
      ..lineTo(size.width - borderRadius, bottomY);
    canvas.drawPath(path, linePaint);
  }

  void _paintProcessingBeam(Canvas canvas, Size size, RRect rrect) {
    // Oscilación senoidal suave de izquierda a derecha (0.0 a 1.0)
    final travel = (math.sin(phase * 2 * math.pi) + 1.0) / 2.0;
    final beamLength = (size.width * 0.28).clamp(36.0, 110.0);
    final startX = (size.width - beamLength) * travel;
    final endX = startX + beamLength;
    final bottomY = size.height;

    // Resplandor difuso del cometa
    final glowPaint = Paint()
      ..color = palette.glowColor.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0)
      ..strokeWidth = physics.beamThickness * 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, bottomY), Offset(endX, bottomY), glowPaint);

    // Núcleo brillante y nítido del haz
    final corePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          palette.beamColor.withValues(alpha: 0.0),
          palette.beamColor,
          palette.colors.first,
          palette.beamColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 0.6, 1.0],
      ).createShader(Rect.fromLTRB(startX, bottomY - 2, endX, bottomY + 2))
      ..strokeWidth = physics.beamThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, bottomY), Offset(endX, bottomY), corePaint);
  }

  @override
  bool shouldRepaint(covariant NanoVoiceBeamPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isProcessing != isProcessing ||
        oldDelegate.palette != palette;
  }
}
