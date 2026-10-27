import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/glass_surface.dart';
import 'nano_animation_policy.dart';
part 'nano_glass_shimmer_painter.dart';

/// Adaptador del panel del búho al cristal universal de Nano. Conserva el haz
/// original; color, opacidad y blur se resuelven en el motor del tema compartido.
class NanoGlass extends StatefulWidget {
  const NanoGlass({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 32,
  });
  final Widget child;
  final double radius, blur;
  @override
  State<NanoGlass> createState() => _NanoGlassState();
}

class _NanoGlassState extends State<NanoGlass>
    with SingleTickerProviderStateMixin, NanoAnimationPolicy {
  late final AnimationController _shimmer;

  /// Mantiene los 4000 ms originales; la política decide cuándo avanza el reloj.
  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
  }

  /// Un cambio de tema también puede desactivar cristal sin cambiar movimiento.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncShimmer();
  }

  /// Conserva el cuadro al suspender; no reinicia el destello al reanudar.
  @override
  void onMotionPolicyChanged() => _syncShimmer();
  void _syncShimmer() {
    if (motionEnabled && NanoThemeExtension.of(context).glassEnabled) {
      if (!_shimmer.isAnimating) _shimmer.repeat();
    } else {
      _shimmer.stop();
    }
  }

  /// Libera el único reloj decorativo junto con el observador de la política.
  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  /// Una lente compartida, una pintura decorativa y el contenido sin atenuación.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: GlassSurface(
      radius: widget.radius,
      blur: widget.blur,
      interactive: false,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (NanoThemeExtension.of(context).glassEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shimmer,
                  builder: (context, _) => CustomPaint(
                    painter: _GlassLiquidShimmerPainter(
                      progress: _shimmer.value,
                      radius: widget.radius,
                    ),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    ),
  );
}
