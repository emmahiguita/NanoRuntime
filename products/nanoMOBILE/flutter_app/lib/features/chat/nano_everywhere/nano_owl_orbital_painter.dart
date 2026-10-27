part of 'nano_owl_orbital_ring.dart';

/// Dibuja el halo orbital mediante el Canvas de Flutter.
class _OrbitalCausticPainter extends CustomPainter {
  _OrbitalCausticPainter({required this.progress, required this.isBusy});

  final double progress;
  final bool isBusy;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 2) / 2;
    final angle = progress * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        transform: GradientRotation(angle),
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: isBusy ? 0.85 : 0.45),
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalCausticPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isBusy != isBusy;
}
