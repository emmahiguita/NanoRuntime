import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
part 'glass_surface_state.part.dart';
part 'glass_surface_body.part.dart';

/// Motor único del cristal de Nano. El fondo se filtra; el contenido conserva
/// su opacidad y contraste. Las preferencias globales afectan todas las capas.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.opacity = .70,
    this.clarity = .85,
    this.blur = 18,
    this.intensity = .65,
    this.tint,
    this.radius = 24,
    this.customBorderRadius,
    this.borderWidth = 1.2,
    this.interactive = true,
    this.tiltIntensity = .045,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
    this.hasBackdropBlur = true,
    this.autoReflect = false,
    this.reflectionController,
    this.specularDrift = 0,
    this.opacityScale = 1,
    this.depth = 1,
    this.isActive = false,
  });
  final Widget child;
  final double opacity, clarity, blur, intensity, radius, borderWidth;
  final double tiltIntensity, specularDrift, opacityScale, depth;
  final Color? tint;
  final BorderRadius? customBorderRadius;
  final bool interactive, hasBackdropBlur, autoReflect, isActive;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width, height;
  final VoidCallback? onTap, onLongPress;

  /// El propietario de un controlador externo conserva su ciclo de vida.
  final AnimationController? reflectionController;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}
