// nano_owl_vector_icon.dart — Silueta vectorial minimalista del búho Nano.
// QUÉ HACE: Renderiza la cara del búho Nano mediante CustomPainter vectorial nítido.
// CÓMO FUNCIONA: Dibuja el contorno con orejas, ojos circulares y pico en trazo puro.
// POR QUÉ: Evita pixelación en tamaños pequeños (22x18 dp) y aporta identidad única de Nano.
library;

import 'package:flutter/material.dart';

class NanoOwlVectorIcon extends StatelessWidget {
  const NanoOwlVectorIcon({
    super.key,
    this.width = 24,
    this.height = 20,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _NanoOwlVectorPainter(color: color),
    );
  }
}

class _NanoOwlVectorPainter extends CustomPainter {
  const _NanoOwlVectorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Contorno del rostro del búho con orejitas estilizadas
    final head = Path()
      ..moveTo(w * 0.16, h * 0.38)
      // Oreja izquierda
      ..cubicTo(w * 0.08, h * 0.14, w * 0.28, h * 0.06, w * 0.38, h * 0.18)
      // Inflexión central entre orejas
      ..quadraticBezierTo(w * 0.50, h * 0.24, w * 0.62, h * 0.18)
      // Oreja derecha
      ..cubicTo(w * 0.72, h * 0.06, w * 0.92, h * 0.14, w * 0.84, h * 0.38)
      // Mejilla derecha y barbilla
      ..cubicTo(w * 0.96, h * 0.68, w * 0.78, h * 0.94, w * 0.50, h * 0.94)
      // Barbilla y mejilla izquierda
      ..cubicTo(w * 0.22, h * 0.94, w * 0.04, h * 0.68, w * 0.16, h * 0.38);

    canvas.drawPath(head, stroke);

    // Ojo izquierdo
    final leftCenter = Offset(w * 0.35, h * 0.56);
    final eyeRadius = w * 0.14;
    canvas.drawCircle(leftCenter, eyeRadius, stroke);
    canvas.drawCircle(leftCenter, eyeRadius * 0.44, fill);

    // Ojo derecho
    final rightCenter = Offset(w * 0.65, h * 0.56);
    canvas.drawCircle(rightCenter, eyeRadius, stroke);
    canvas.drawCircle(rightCenter, eyeRadius * 0.44, fill);

    // Pico triangular sutil
    final beak = Path()
      ..moveTo(w * 0.46, h * 0.63)
      ..lineTo(w * 0.50, h * 0.74)
      ..lineTo(w * 0.54, h * 0.63)
      ..close();
    canvas.drawPath(beak, fill);
  }

  @override
  bool shouldRepaint(covariant _NanoOwlVectorPainter oldDelegate) =>
      oldDelegate.color != color;
}
