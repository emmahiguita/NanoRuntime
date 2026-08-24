import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';

/// Card de glass INTERACTIVA e hiperrealista (reutilizable, DRY).
///
/// Efectos 3D reales del design system:
/// - reflejo especular CONTINUO (AnimationController.repeat → shimmer del vidrio).
/// - destello especular que SIGUE al puntero (specularDrift).
/// - tilt 3D en perspectiva (Matrix4 + rotateX/Y) que se inclina hacia el toque.
/// - glass óptico (blur + bisel + reflejo) con accent.
///
/// Una sola implementación para el composer y las cards secundarias — el mismo
/// efecto profesional en todo el dashboard.
class InteractiveGlassCard extends StatefulWidget {
  final Widget child;
  final Color? accent;
  final double borderStrength;
  final double reflectionStrength;
  final double blurSigma;
  final double glassOpacityScale;
  final double tiltIntensity;

  /// shimmer: reflejo especular continuo (AnimationController.repeat). false →
  /// glass estático (sin ticker, para tiles ligeros). El tilt 3D sigue activo.
  final bool shimmer;

  const InteractiveGlassCard({
    super.key,
    required this.child,
    this.accent,
    this.borderStrength = 0.5,
    this.reflectionStrength = 0.42,
    this.blurSigma = 14,
    this.glassOpacityScale = 0.85,
    this.tiltIntensity = 0.18,
    this.shimmer = true,
  });

  @override
  State<InteractiveGlassCard> createState() => _InteractiveGlassCardState();
}

class _InteractiveGlassCardState extends State<InteractiveGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reflection = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.shimmer) _reflection.repeat();
  }

  double _specularDrift = 0.0;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  void _onPointer(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(e.position);
    setState(() {
      final nx = local.dx / box.size.width;
      final ny = local.dy / box.size.height;
      _specularDrift = (nx - 0.5) * 0.5;
      _tiltY = (nx - 0.5) * widget.tiltIntensity;
      _tiltX = -(ny - 0.5) * widget.tiltIntensity;
    });
  }

  void _reset() {
    if (_tiltX == 0 && _tiltY == 0) return;
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Listener(
      onPointerDown: _onPointer,
      onPointerMove: _onPointer,
      onPointerUp: (_) => _reset(),
      onPointerCancel: (_) => _reset(),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..rotateX(_tiltX)
          ..rotateY(_tiltY),
        child: NanoOpticalSurface(
          borderRadius: NanoRadius.large,
          borderStrength: widget.borderStrength,
          reflectionStrength: widget.reflectionStrength,
          blurSigma: widget.blurSigma,
          glassOpacityScale: widget.glassOpacityScale,
          accent: widget.accent ?? colors.accentCyan,
          reflectionController: _reflection,
          specularDrift: _specularDrift,
          child: widget.child,
        ),
      ),
    );
  }
}
