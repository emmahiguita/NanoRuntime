/// AUTOMATION-INBOX-HALO — Borde animado liviano para la bandeja real.
///
/// QUÉ HACE: desplaza un reflejo corto por el contorno de la tarjeta.
/// CÓMO: repinta solo el borde; no reconstruye ni altera sus datos.
/// POR QUÉ: aporta respuesta visual tipo metal sin shaders ni dependencias web.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AutomationInboxHalo extends StatefulWidget {
  final Color color;
  final BorderRadius borderRadius;

  const AutomationInboxHalo({super.key, required this.color, required this.borderRadius});

  @override
  State<AutomationInboxHalo> createState() => _AutomationInboxHaloState();
}

class _AutomationInboxHaloState extends State<AutomationInboxHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta la preferencia del sistema y evita animación/batería innecesaria.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0.12;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: _HaloPainter(
              progress: _controller.value,
              color: widget.color,
              radius: widget.borderRadius,
            ),
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  final double progress;
  final Color color;
  final BorderRadius radius;

  const _HaloPainter({required this.progress, required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(1);
    final rrect = radius.toRRect(ring);
    final shader = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.08),
        color.withValues(alpha: 0.92),
        Colors.white.withValues(alpha: 0.70),
        Colors.transparent,
      ],
      stops: const [0.0, 0.60, 0.76, 0.80, 1.0],
    ).createShader(rect);

    // Un único trazo mantiene el efecto estable incluso en móviles modestos.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.radius != radius;
  }
}
