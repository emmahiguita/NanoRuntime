import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Fondo de aurora LÍQUIDA hiperrealista (sin shader → sin riesgo de pantalla
/// negra). Blobs de gradiente radial que DERIVAN suavemente (movimiento
/// pseudo-fluido con sin/cos) sobre un gradiente profundo + resplandores que
/// respiran. Renders en CustomPaint dentro de un RepaintBoundary (barato).
///
/// UI-REV-08: el fondo se adapta al modo del tema. En OSCURO conserva los
/// blobs de acento del tema sobre el fondo profundo original. En CLARO pinta
/// la gama azul de la barra de navegación (NAV-BAR-FIX-05) sobre un
/// lienzo claro — el modo claro de toda la app hereda el fondo "tipo dev".
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
            isDark: colors is NanoDarkColors,
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
  final bool isDark;
  final double opacity;

  _LiquidPainter({
    required this.t,
    required this.colors,
    required this.isDark,
    required this.opacity,
  });

  // NAV-BAR-FIX-05 — gama azul de la barra de navegación (NanoNavTokens:
  // cyan 5CE7FF, electricBlue 42B7FF, accentBlue 2A7FFF) para el modo claro.
  // El lienzo pasa de cálido a frío: la identidad clásica es el azul cósmico
  // de la barra, no la naranja anterior.
  static const _lightBase = [
    Color(0xFFF5FAFF),
    Color(0xFFF0F6FF),
    Color(0xFFE9F1FF),
  ];
  static const _lightBlobs = [
    (Color(0xFF5CE7FF), 0.20), // cyan barra
    (Color(0xFF42B7FF), 0.16), // electricBlue barra
    (Color(0xFF2A7FFF), 0.14), // accentBlue barra
  ];
  static const _lightSpark = Color(0xFF5CE7FF);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Fondo profundo (oscuro) o lienzo claro con tinte cálido.
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF05080F), Color(0xFF0B1220), Color(0xFF08101C)]
            : _lightBase,
      ).createShader(rect);
    canvas.drawRect(rect, base);

    if (isDark) {
      _paintDark(canvas, size);
    } else {
      _paintLight(canvas, size);
    }
  }

  /// Rama oscura original: blobs de acento del tema + partículas cyan.
  void _paintDark(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final blobs = [
      _Blob(colors.accentCyan, phase: 0.0, amp: 0.6, rad: 0.9),
      _Blob(colors.accentLavender, phase: 2.1, amp: 0.7, rad: 1.1),
      _Blob(colors.accentBlue, phase: 4.2, amp: 0.5, rad: 0.8),
    ];
    for (final b in blobs) {
      final center = _driftCenter(w, h, b, t);
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
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, glow);
    }

    final sparkColor = colors.accentCyan;
    for (var i = 0; i < 7; i++) {
      _paintSpark(canvas, w, h, t, i, sparkColor, 0.45, 0.014);
    }
  }

  /// Rama clara (UI-REV-08): blobs azules visibles sobre lienzo claro —
  /// alphas mayores que en oscuro porque el color se diluye sobre blanco.
  void _paintLight(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const phases = [0.0, 2.1, 4.2];
    for (var i = 0; i < _lightBlobs.length; i++) {
      final (color, alpha) = _lightBlobs[i];
      final b = _Blob(
        color,
        phase: phases[i],
        amp: 0.6 + i * 0.05,
        rad: 0.9 + i * 0.1,
      );
      final center = _driftCenter(w, h, b, t);
      final r =
          math.min(w, h) *
          b.rad *
          (0.9 + 0.1 * math.sin(2 * math.pi * (t * 1.3 + b.phase)));
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: alpha * opacity),
            b.color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, glow);
    }

    for (var i = 0; i < 7; i++) {
      _paintSpark(canvas, w, h, t, i, _lightSpark, 0.30, 0.011);
    }
  }

  /// Centro del blob en píxeles (deriva con sin/cos sobre el viewport).
  Offset _driftCenter(double w, double h, _Blob b, double t) {
    final dx = w * (0.5 + 0.5 * b.amp * math.sin(2 * math.pi * (t + b.phase)));
    final dy =
        h * (0.5 + 0.5 * b.amp * math.cos(2 * math.pi * (t * 0.9 + b.phase)));
    return Offset(dx, dy);
  }

  void _paintSpark(
    Canvas canvas,
    double w,
    double h,
    double t,
    int i,
    Color color,
    double alpha,
    double sizeRatio,
  ) {
    final px =
        w * (0.5 + 0.5 * 0.55 * math.sin(2 * math.pi * (t * 1.4 + i * 0.37)));
    final py =
        h * (0.5 + 0.5 * 0.55 * math.cos(2 * math.pi * (t * 1.1 + i * 0.53)));
    final pr =
        math.min(w, h) *
        sizeRatio *
        (0.8 + 0.4 * math.sin(2 * math.pi * (t * 2.2 + i)));
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha * opacity),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(px, py), radius: pr * 3.2));
    canvas.drawCircle(Offset(px, py), pr * 3.2, halo);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter old) =>
      old.t != t || old.opacity != opacity || old.isDark != isDark;
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
