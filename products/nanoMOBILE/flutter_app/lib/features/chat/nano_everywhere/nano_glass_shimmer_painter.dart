part of 'nano_glass.dart';

/// Conserva la trayectoria y pintura del destello original; el State posee su reloj.
class _GlassLiquidShimmerPainter extends CustomPainter {
  _GlassLiquidShimmerPainter({required this.progress, required this.radius});

  final double progress;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Haz diagonal continuo que barre sutilmente la superficie de cristal
    const angle = -math.pi / 5;
    final travel = size.width + size.height * 1.5;
    final currentOffset = -size.height * 0.5 + travel * progress;

    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.09),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromLTWH(currentOffset, 0, size.width * 0.65, size.height),
          );

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.rotate(angle);
    canvas.drawRect(
      Rect.fromLTWH(
        -size.width,
        currentOffset,
        size.width * 3,
        size.height * 0.5,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassLiquidShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
