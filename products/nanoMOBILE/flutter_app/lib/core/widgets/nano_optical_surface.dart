import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'glass_surface.dart';

enum NanoSurfaceGeometry { roundedRectangle, capsule, circle }

/// Adaptador compatible: las tarjetas existentes usan el mismo cristal global.
class NanoOpticalSurface extends StatelessWidget {
  const NanoOpticalSurface({
    super.key,
    required this.child,
    this.geometry = NanoSurfaceGeometry.roundedRectangle,
    this.borderRadius = NanoRadius.large, // 24.0 por defecto
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blurSigma = 18.0,
    this.borderStrength = 1.0,
    this.reflectionStrength = 1.0,
    this.depth = 1.0,
    this.accent,
    this.isActive = false,
    this.hasBackdropBlur = true,
    this.reflectionController,
    this.specularDrift = 0.0,
    this.glassOpacityScale = 1.0,
    this.onTap,
    this.onLongPress,
    this.tilt = true,
    this.tiltIntensity = 0.045,
    this.autoReflect = false,
  });

  final Widget child;
  final NanoSurfaceGeometry geometry;
  final double borderRadius;
  final BorderRadius? customBorderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;
  final double borderStrength;
  final double reflectionStrength;
  final double depth;
  final Color? accent;
  final bool isActive;
  final bool hasBackdropBlur;
  final AnimationController? reflectionController;
  final double specularDrift;

  /// Escala la opacidad del sustrato de vidrio (cards laterales más
  /// transparentes que la hero). 1.0 = niveles de token originales.
  final double glassOpacityScale;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Inclina la superficie en 3D (rotationX/Y) siguiendo el puntero,
  /// imitando el giro de un panel de vidrio bajo la luz. Opt-in para no
  /// alterar cards estáticas por defecto.
  final bool tilt;

  /// Radiánes máximos de rotación en el borde (puntero en un extremo).
  final double tiltIntensity;

  /// Activa el reflejo ambiental solo mientras la superficie está visible.
  final bool autoReflect;

  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: geometry == NanoSurfaceGeometry.roundedRectangle
        ? borderRadius
        : 999,
    customBorderRadius: customBorderRadius,
    padding: padding ?? EdgeInsets.zero,
    margin: margin,
    width: width,
    height: height,
    blur: blurSigma,
    borderWidth: borderStrength,
    intensity: reflectionStrength,
    depth: depth,
    tint: accent,
    isActive: isActive,
    hasBackdropBlur: hasBackdropBlur,
    reflectionController: reflectionController,
    specularDrift: specularDrift,
    opacityScale: glassOpacityScale,
    onTap: onTap,
    onLongPress: onLongPress,
    interactive: tilt,
    tiltIntensity: tiltIntensity,
    autoReflect: autoReflect,
    child: child,
  );
}
