import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';

/// Tarjeta interactiva sin un segundo controlador ni una segunda inclinación.
/// El motor compartido pausa reflejos al ocultarse o reducir movimiento.
class InteractiveGlassCard extends StatelessWidget {
  const InteractiveGlassCard({
    super.key,
    required this.child,
    this.accent,
    this.borderStrength = .5,
    this.reflectionStrength = .42,
    this.blurSigma = 14,
    this.glassOpacityScale = .85,
    this.tiltIntensity = .045,
    this.shimmer = true,
  });
  final Widget child;
  final Color? accent;
  final double borderStrength, reflectionStrength, blurSigma;
  final double glassOpacityScale, tiltIntensity;
  final bool shimmer;

  @override
  Widget build(BuildContext context) => NanoOpticalSurface(
    borderStrength: borderStrength,
    reflectionStrength: reflectionStrength,
    blurSigma: blurSigma,
    glassOpacityScale: glassOpacityScale,
    tiltIntensity: tiltIntensity,
    accent: accent,
    autoReflect: shimmer,
    child: child,
  );
}
