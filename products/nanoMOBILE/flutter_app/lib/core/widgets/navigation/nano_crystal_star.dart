// nano_crystal_star.dart — Emblema de estrella de cristal radiante para Nano AI.
//
// QUÉ HACE:
// Renderiza el astro/estrella 3D de 4 puntas facetada en cristal Liquid Glass,
// con reflejos especulares, gradientes cósmicos y aura violeta/lavanda.
//
// CÓMO FUNCIONA:
// - Dibuja 4 facetas triangulares convexas/cóncavas mediante curvas de Bézier cuadráticas.
// - Aplica sombreado especular multidireccional imitando refracción de vidrio óptico.
// - Proyecta un núcleo brillante con resplandor central suave.
//
// POR QUÉ:
// Representa la identidad visual nativa de Nano AI en el FAB (< 140 líneas, SOLID).
library;

import 'package:flutter/material.dart';

class NanoCrystalStar extends StatelessWidget {
  const NanoCrystalStar({
    super.key,
    this.size = 28.0,
    required this.isDark,
  });

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrystalStarPainter(isDark: isDark),
      ),
    );
  }
}

class _CrystalStarPainter extends CustomPainter {
  const _CrystalStarPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOuter = size.width * 0.46;
    final rInner = rOuter * 0.22;

    final center = Offset(cx, cy);

    // 0. Resplandor radial de fondo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFF818CF8) : const Color(0xFFA78BFA))
              .withValues(alpha: isDark ? 0.45 : 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: rOuter * 1.15));
    canvas.drawCircle(center, rOuter * 1.1, glowPaint);

    // Puntas: Superior, Derecha, Inferior, Izquierda
    final pTop = Offset(cx, cy - rOuter);
    final pRight = Offset(cx + rOuter, cy);
    final pBottom = Offset(cx, cy + rOuter);
    final pLeft = Offset(cx - rOuter, cy);

    // Faceta 1: Superior-Izquierda (Brillo principal especular)
    final pathTL = Path()
      ..moveTo(cx, cy)
      ..lineTo(pTop.dx, pTop.dy)
      ..quadraticBezierTo(cx - rInner, cy - rInner, pLeft.dx, pLeft.dy)
      ..close();

    final paintTL = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFFFFFFFF), const Color(0xFFC7D2FE)]
            : [const Color(0xFFFFFFFF), const Color(0xFFE0E7FF)],
      ).createShader(Rect.fromPoints(pLeft, pTop));
    canvas.drawPath(pathTL, paintTL);

    // Faceta 2: Superior-Derecha (Luz violeta suave)
    final pathTR = Path()
      ..moveTo(cx, cy)
      ..lineTo(pTop.dx, pTop.dy)
      ..quadraticBezierTo(cx + rInner, cy - rInner, pRight.dx, pRight.dy)
      ..close();

    final paintTR = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: isDark
            ? [const Color(0xFFA5B4FC), const Color(0xFF818CF8)]
            : [const Color(0xFFDDD6FE), const Color(0xFFC4B5FD)],
      ).createShader(Rect.fromPoints(pTop, pRight));
    canvas.drawPath(pathTR, paintTR);

    // Faceta 3: Inferior-Derecha (Sombra rica en violeta/índigo)
    final pathBR = Path()
      ..moveTo(cx, cy)
      ..lineTo(pRight.dx, pRight.dy)
      ..quadraticBezierTo(cx + rInner, cy + rInner, pBottom.dx, pBottom.dy)
      ..close();

    final paintBR = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: isDark
            ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
            : [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
      ).createShader(Rect.fromPoints(pRight, pBottom));
    canvas.drawPath(pathBR, paintBR);

    // Faceta 4: Inferior-Izquierda (Refracción media)
    final pathBL = Path()
      ..moveTo(cx, cy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..quadraticBezierTo(cx - rInner, cy + rInner, pLeft.dx, pLeft.dy)
      ..close();

    final paintBL = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: isDark
            ? [const Color(0xFF4F46E5), const Color(0xFF818CF8)]
            : [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      ).createShader(Rect.fromPoints(pBottom, pLeft));
    canvas.drawPath(pathBL, paintBL);

    // 5. Destello central blanco brillante (Core Gleam)
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: rInner * 1.5));
    canvas.drawCircle(center, rInner * 1.4, corePaint);

    // 6. Líneas sutiles de facetado
    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.45 : 0.70)
      ..strokeWidth = 0.65
      ..style = PaintingStyle.stroke;

    canvas.drawLine(pTop, pBottom, creasePaint);
    canvas.drawLine(pLeft, pRight, creasePaint);
  }

  @override
  bool shouldRepaint(covariant _CrystalStarPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
