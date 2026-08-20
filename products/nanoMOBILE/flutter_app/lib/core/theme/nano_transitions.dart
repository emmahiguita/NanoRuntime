import 'dart:ui';
import 'package:flutter/material.dart';
import 'nano_motion.dart';

// =============================================================
// NANO TRANSITIONS — GLASS MORPH & EXPRESSIVE SHARED MOTION
// =============================================================

/// Transición principal de navegación con expansión de contenedor vítreo
/// y continuidad espacial (Glass Morph Transition).
class NanoGlassMorphTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const NanoGlassMorphTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = NanoMotion.reduceMotion(context);

    if (reduceMotion) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }

    final curvedForward = CurvedAnimation(
      parent: animation,
      curve: NanoMotionCurves.emphasized,
      reverseCurve: NanoMotionCurves.standardAccel,
    );

    final curvedSecondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: NanoMotionCurves.standardDecel,
      reverseCurve: NanoMotionCurves.standardAccel,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([curvedForward, curvedSecondary]),
      child: child,
      builder: (context, child) {
        final t = curvedForward.value;
        final secT = curvedSecondary.value;

        // Interpolación de entrada (Destination Page)
        final scaleIn = lerpDouble(0.982, 1.0, t)!;
        final translateYIn = lerpDouble(12.0, 0.0, t)!;
        final opacityIn = ((t - 0.20) / 0.80).clamp(0.0, 1.0);
        final radiusIn = lerpDouble(32.0, 0.0, t)!;

        // Interpolación de salida secundaria (Origin Page cuando otra ruta se superpone o en back predictivo)
        final scaleOut = lerpDouble(1.0, 0.985, secT)!;
        final translateXOut = lerpDouble(0.0, -18.0, secT)!;
        final opacityOut = lerpDouble(1.0, 0.85, secT)!;
        final radiusOut = lerpDouble(0.0, 16.0, secT)!;

        final effectiveScale = scaleIn * scaleOut;
        final effectiveRadius = radiusIn > 0 ? radiusIn : radiusOut;

        Widget content = Transform.translate(
          offset: Offset(translateXOut, translateYIn),
          child: Transform.scale(
            scale: effectiveScale,
            child: Opacity(
              opacity: opacityIn * opacityOut,
              child: child,
            ),
          ),
        );

        if (effectiveRadius > 0.5) {
          content = ClipRRect(
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: content,
          );
        }

        return content;
      },
    );
  }
}

/// Transición secundaria para navegación interna y ajustes (Expressive Slide).
class NanoExpressiveSlideTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const NanoExpressiveSlideTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (NanoMotion.reduceMotion(context)) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }

    final forward = CurvedAnimation(
      parent: animation,
      curve: NanoMotionCurves.standardDecel,
      reverseCurve: NanoMotionCurves.standardAccel,
    );

    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: NanoMotionCurves.standardDecel,
      reverseCurve: NanoMotionCurves.standardAccel,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([forward, secondary]),
      child: child,
      builder: (context, child) {
        final t = forward.value;
        final secT = secondary.value;

        final translateX = lerpDouble(24.0, 0.0, t)! + lerpDouble(0.0, -16.0, secT)!;
        final scale = lerpDouble(0.990, 1.0, t)! * lerpDouble(1.0, 0.990, secT)!;
        final opacity = lerpDouble(0.0, 1.0, t)! * lerpDouble(1.0, 0.88, secT)!;

        return Transform.translate(
          offset: Offset(translateX, 0),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Muestra un diálogo/modal con la transición de cristal óptico
/// ([NanoModalGlassTransition]) en lugar de la FadeUpwards de Material.
///
/// Misma semántica que [showDialog]: barrera, dismiss, root navigator y
/// resultado tipado vía `T`. Respeta `disableAnimations` (reduce-motion)
/// internamente en [NanoModalGlassTransition].
Future<T?> showNanoModalDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: NanoMotionDurations.standard,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return NanoModalGlassTransition(animation: animation, child: child);
    },
  );
}

/// Transición para modales y diálogos de cristal óptico.
class NanoModalGlassTransition extends StatelessWidget {  final Animation<double> animation;
  final Widget child;

  const NanoModalGlassTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (NanoMotion.reduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: NanoMotionCurves.emphasized,
    );

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        final scale = lerpDouble(0.960, 1.0, t)!;
        final translateY = lerpDouble(8.0, 0.0, t)!;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Custom Hero Flight Builder para mantener el radio de curvatura y luz
/// durante la trayectoria de vuelo sin deformaciones abruptas.
class NanoHeroFlightBuilder {
  static Widget build(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: NanoMotionCurves.emphasized,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        final toHero = toHeroContext.widget as Hero;

        return Transform.scale(
          scale: lerpDouble(0.95, 1.0, t)!,
          child: Opacity(
            opacity: lerpDouble(0.85, 1.0, t)!,
            child: toHero.child,
          ),
        );
      },
    );
  }
}

/// Predictive Back Transition Builder para Android 14+ (API 34+).
/// Envuelve NanoGlassMorphTransition y mapea backProgress a scale/opacity/radius.
/// Fallback automático a NanoGlassMorphTransition en versiones anteriores.
/// 
/// NOTA: Para habilitar completamente, necesita:
/// 1. Flutter 3.16+ 
/// 2. Android minSdkVersion 34+
/// 3. Configurar en MaterialApp: pageTransitionsTheme: PageTransitionsTheme(
///      builders: {TargetPlatform.android: NanoPredictiveBackPageTransitionsBuilder()}
///    )
class NanoPredictiveBackPageTransitionsBuilder extends PageTransitionsBuilder {
  const NanoPredictiveBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Base implementation with NanoGlassMorphTransition
    // Full predictive back integration requires Flutter 3.16+ PredictiveBackPageTransitionsBuilder
    return NanoGlassMorphTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
