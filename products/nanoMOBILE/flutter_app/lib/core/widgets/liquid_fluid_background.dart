import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Fondo de aurora LÍQUIDA hiperrealista (sin shader → sin riesgo de pantalla
/// negra). Blobs de gradiente radial que DERIVAN suavemente (movimiento
/// pseudo-fluido con sin/cos) sobre un gradiente profundo + resplandores que
/// respiran. Renders en CustomPaint dentro de un RepaintBoundary (barato).
class LiquidFluidBackground extends StatefulWidget {
  final double opacity;
  const LiquidFluidBackground({super.key, this.opacity = 1.0});

  @override
  State<LiquidFluidBackground> createState() => _LiquidFluidBackgroundState();
}

class _LiquidFluidBackgroundState extends State<LiquidFluidBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NanoThemeExtension.of(context);
    final colors = theme.colors;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _LiquidPainter(
            t: _controller.value,
            colors: colors,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double t;
  final dynamic colors;
  final double opacity;

  _LiquidPainter({
    required this.t,
    required this.colors,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Fondo profundo.
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF05080F), Color(0xFF0B1220), Color(0xFF08101C)],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    // Blobs de aurora líquida que derivan (radio grande → luz suave).
    final blobs = [
      _Blob(colors.accentCyan, phase: 0.0, amp: 0.6, rad: 0.9),
      _Blob(colors.accentLavender, phase: 2.1, amp: 0.7, rad: 1.1),
      _Blob(colors.accentBlue, phase: 4.2, amp: 0.5, rad: 0.8),
    ];
    for (final b in blobs) {
      final dx =
          w * (0.5 + 0.5 * b.amp * math.sin(2 * math.pi * (t + b.phase)));
      final dy =
          h * (0.5 + 0.5 * b.amp * math.cos(2 * math.pi * (t * 0.9 + b.phase)));
      final r =
          math.min(w, h) *
          b.rad *
          (0.9 + 0.1 * math.sin(2 * math.pi * (t * 1.3 + b.phase)));
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: 0.22 * opacity),
            b.color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(dx, dy), radius: r));
      canvas.drawCircle(Offset(dx, dy), r, glow);
    }

    // Partículas de brillo que derivan + pulsan (hiperrealista).
    final sparkColor = colors.accentCyan;
    for (var i = 0; i < 7; i++) {
      final px =
          w * (0.5 + 0.5 * 0.55 * math.sin(2 * math.pi * (t * 1.4 + i * 0.37)));
      final py =
          h * (0.5 + 0.5 * 0.55 * math.cos(2 * math.pi * (t * 1.1 + i * 0.53)));
      final pr =
          math.min(w, h) *
          0.014 *
          (0.8 + 0.4 * math.sin(2 * math.pi * (t * 2.2 + i)));
      final halo = Paint()
        ..shader =
            RadialGradient(
              colors: [
                sparkColor.withValues(alpha: 0.45 * opacity),
                sparkColor.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(px, py), radius: pr * 3.2),
            );
      canvas.drawCircle(Offset(px, py), pr * 3.2, halo);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter old) =>
      old.t != t || old.opacity != opacity;
}

class _Blob {
  final Color color;
  final double phase;
  final double amp;
  final double rad;
  const _Blob(
    this.color, {
    required this.phase,
    required this.amp,
    required this.rad,
  });
}
