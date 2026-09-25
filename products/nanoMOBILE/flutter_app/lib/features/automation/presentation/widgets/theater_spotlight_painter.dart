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
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF44FFCE).withValues(alpha: 0.16),
          const Color(0xFF10B981).withValues(alpha: 0.07),
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
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5A0).withValues(alpha: 0.10),
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
