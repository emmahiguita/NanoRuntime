/// THEATER-SPOTLIGHT-PAINTER — Iluminación escénica estilo iOS Glassmorphism.
///
/// QUÉ HACE:
/// Proyecta una iluminación ambiental suave y difusa estilo iOS / Apple VisionOS,
/// sin haces geométricos duros, creando un aura cinematográfica natural detrás de la tarjeta.
///
/// CÓMO FUNCIONA:
/// Dibuja un gradiente radial cenital ultrasuave con atenuación cúbica y resplandor
/// de fondo esmeralda/blanco, simulando la iluminación difusa de estudio (softbox).
///
/// POR QUÉ:
/// Reemplaza haces cónicos artificiales por iluminación óptica profesional de cristal iOS,
/// manteniendo 60 FPS estables y estricta fidelidad estética < 200 líneas.
library;

import 'package:flutter/material.dart';

class TheaterSpotlightPainter extends CustomPainter {
  const TheaterSpotlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;

    // Resplandor cenital difuso estilo iOS Softbox (sin bordes duros)
    final softboxCenter = Offset(width * 0.50, -height * 0.15);
    final softboxPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.12),
              const Color(0xFF1D4ED8).withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: softboxCenter, radius: width * 0.65),
          );

    canvas.drawCircle(softboxCenter, width * 0.65, softboxPaint);

    // Resplandor inferior de contacto ambiental (Ambient Occlusion suelo)
    final floorGlowCenter = Offset(width * 0.50, height * 1.05);
    final floorPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF2563EB).withValues(alpha: 0.08),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(center: floorGlowCenter, radius: width * 0.50),
          );

    canvas.drawCircle(floorGlowCenter, width * 0.50, floorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
