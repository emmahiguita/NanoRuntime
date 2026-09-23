// automation_glass_360.dart — Efecto Glassmorphism 360° con halo perimetral rotativo.
// QUÉ HACE: Proyecta un haz de luz envolvente continuo de 360° con desenfoque de cristal líquido.
// CÓMO FUNCIONA: Usa SweepGradient animado (0..2π) + CustomPainter aislado con RepaintBoundary.
// POR QUÉ: Eleva la jerarquía visual de la Hero Card a Material 3 Expressive sin fugas de GPU (< 200 líneas).
library;

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Contenedor de cristal líquido con borde de luz giratorio continuo en 360 grados.
class AutomationGlass360 extends StatefulWidget {
  const AutomationGlass360({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.accentColor = const Color(0xFF10B981),
    this.isActionable = false,
  });

  final Widget child;
  final double borderRadius;
  final Color accentColor;
  final bool isActionable;

  @override
  State<AutomationGlass360> createState() => _AutomationGlass360State();
}

class _AutomationGlass360State extends State<AutomationGlass360>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _rotation;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_foreground && !reduceMotion) {
      if (!_rotation.isAnimating) _rotation.repeat();
    } else {
      if (_rotation.isAnimating) _rotation.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(widget.borderRadius);

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Capa de borde lumínico rotativo 360°
          Positioned.fill(
            child: reduceMotion
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) => CustomPaint(
                      painter: _GlassBorder360Painter(
                        phase: _rotation.value,
                        accent: widget.accentColor,
                        borderRadius: widget.borderRadius,
                        isActionable: widget.isActionable,
                      ),
                    ),
                  ),
          ),

          // 2. Cristal templado interior con BackdropFilter
          ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBorder360Painter extends CustomPainter {
  const _GlassBorder360Painter({
    required this.phase,
    required this.accent,
    required this.borderRadius,
    required this.isActionable,
  });

  final double phase;
  final Color accent;
  final double borderRadius;
  final bool isActionable;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final angle = phase * 2 * math.pi;

    // Gradiente angular rotativo 360° para el haz de luz perimetral
    final sweep = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: math.pi * 2,
      transform: GradientRotation(angle),
      colors: [
        accent.withValues(alpha: isActionable ? 0.85 : 0.45),
        const Color(0xFF22D3EE).withValues(alpha: 0.50), // Cian
        const Color(0xFFA855F7).withValues(alpha: 0.20), // Púrpura
        Colors.white.withValues(alpha: 0.08),
        accent.withValues(alpha: isActionable ? 0.85 : 0.45),
      ],
      stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
    );

    final borderPaint = Paint()
      ..shader = sweep.createShader(rect)
      ..strokeWidth = isActionable ? 1.8 : 1.3
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, borderPaint);

    // Resplandor exterior difuso si hay elementos accionables
    if (isActionable) {
      final glowPaint = Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(rrect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassBorder360Painter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.accent != accent ||
        oldDelegate.isActionable != isActionable;
  }
}
