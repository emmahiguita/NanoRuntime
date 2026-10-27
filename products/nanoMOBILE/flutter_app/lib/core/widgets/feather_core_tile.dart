// QUÉ: superficie FeatherCore compartida por los iconos.
// CÓMO: compone reflejo y faceta sin controladores de animación.
// POR QUÉ: mantiene el acabado existente en una sola pieza breve.
import 'package:flutter/material.dart';

class FeatherCoreTile extends StatelessWidget {
  const FeatherCoreTile({
    super.key,
    required this.size,
    required this.child,
    required this.accent,
    required this.glow,
  });
  final double size;
  final Widget child;
  final Color accent;
  final bool glow;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(size * .28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xD9274666), Color(0xE50B1A2C)]
              : const [Color(0xFFFFFFFF), Color(0xFFEAF4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .28)
              : const Color(0xFFBBD7F4),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .24)
                : const Color(0x260D4B8F),
            blurRadius: size * .20,
            offset: Offset(0, size * .07),
          ),
          if (glow)
            BoxShadow(
              color: accent.withValues(alpha: isDark ? .12 : .09),
              blurRadius: size * .24,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 1,
              left: size * .12,
              right: size * .12,
              height: size * .18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? .20 : .82),
                      Colors.white.withValues(alpha: isDark ? .01 : .06),
                    ],
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: Size.square(size),
              painter: _CrystalFacetPainter(
                color: Colors.white.withValues(alpha: isDark ? .15 : .72),
                radius: size * .28,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _CrystalFacetPainter extends CustomPainter {
  const _CrystalFacetPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    const inset = 2.4;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius - inset)),
      paint,
    );
    final glint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: .7), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width * .56, size.height * .56))
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .17, size.height * .28),
      Offset(size.width * .37, size.height * .12),
      glint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrystalFacetPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
