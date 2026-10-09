import 'package:flutter/material.dart';

/// Ícono de Cristal 3D / Estrella Poliédrica de IA estilo Spatial Glass.
class Nano3dCrystalIcon extends StatelessWidget {
  final double size;
  final bool isGlowing;
  final Color primaryColor;
  final Color secondaryColor;

  const Nano3dCrystalIcon({
    super.key,
    this.size = 36,
    this.isGlowing = true,
    this.primaryColor = const Color(0xFF4DD7FF),
    this.secondaryColor = const Color(0xFF1E88E5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0C1D30).withValues(alpha: 0.85),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 0.9,
        ),
        boxShadow: [
          if (isGlowing) ...[
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: secondaryColor.withValues(alpha: 0.25),
              blurRadius: 6,
            ),
          ],
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.62),
          painter: _CrystalPainter(
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
        ),
      ),
    );
  }
}

class _CrystalPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _CrystalPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width;
    final h = size.height;

    // Facetas del octaedro / diamante 3D
    final top = Offset(cx, 0);
    final bottom = Offset(cx, h);
    final left = Offset(0, cy);
    final right = Offset(w, cy);
    final center = Offset(cx, cy);

    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Faceta Superior Izquierda
    final pathTopLeft = Path()..moveTo(top.dx, top.dy)..lineTo(left.dx, left.dy)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(
      pathTopLeft,
      Paint()..shader = LinearGradient(
        colors: [primaryColor.withValues(alpha: 0.75), secondaryColor.withValues(alpha: 0.35)],
      ).createShader(Rect.fromLTWH(0, 0, cx, cy)),
    );

    // 2. Faceta Superior Derecha (Brillo principal)
    final pathTopRight = Path()..moveTo(top.dx, top.dy)..lineTo(right.dx, right.dy)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(
      pathTopRight,
      Paint()..shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.90), primaryColor.withValues(alpha: 0.60)],
      ).createShader(Rect.fromLTWH(cx, 0, cx, cy)),
    );

    // 3. Faceta Inferior Izquierda
    final pathBottomLeft = Path()..moveTo(bottom.dx, bottom.dy)..lineTo(left.dx, left.dy)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(
      pathBottomLeft,
      Paint()..shader = LinearGradient(
        colors: [secondaryColor.withValues(alpha: 0.60), const Color(0xFF0D253A)],
      ).createShader(Rect.fromLTWH(0, cy, cx, cy)),
    );

    // 4. Faceta Inferior Derecha
    final pathBottomRight = Path()..moveTo(bottom.dx, bottom.dy)..lineTo(right.dx, right.dy)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(
      pathBottomRight,
      Paint()..shader = LinearGradient(
        colors: [primaryColor.withValues(alpha: 0.50), secondaryColor.withValues(alpha: 0.70)],
      ).createShader(Rect.fromLTWH(cx, cy, cx, cy)),
    );

    // Dibujar aristas de diamante
    canvas.drawPath(pathTopLeft, linePaint);
    canvas.drawPath(pathTopRight, linePaint);
    canvas.drawPath(pathBottomLeft, linePaint);
    canvas.drawPath(pathBottomRight, linePaint);

    // Destello de luz central
    canvas.drawCircle(
      center,
      1.8,
      Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
