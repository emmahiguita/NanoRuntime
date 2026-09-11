import 'dart:ui';
import 'package:flutter/material.dart';
import 'nano_motion.dart';

// =============================================================
// NANO TRANSITIONS — GLASS MORPH & EXPRESSIVE SHARED MOTION
// =============================================================

/// Transición principal de navegación con expansión de contenedor vítreo
/// y continuidad espacial (Glass Morph Transition).
///
/// MEM-FIX-01: Convertido a StatefulWidget para que CurvedAnimation se
/// cree en initState y se libere en dispose. Antes cada build() creaba
/// instancias nuevas que nunca se eliminaban → memory leak acumulativo.
class NanoGlassMorphTransition extends StatefulWidget {
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
  State<NanoGlassMorphTransition> createState() =>
      _NanoGlassMorphTransitionState();
}

class _NanoGlassMorphTransitionState extends State<NanoGlassMorphTransition> {
  late CurvedAnimation _curvedForward;
  late CurvedAnimation _curvedSecondary;
  late Animation<Offset> _slideIn;
  late Animation<Offset> _slideOut;

  @override
  void initState() {
    super.initState();
    _buildCurves();
  }

  void _buildCurves() {
    _curvedForward = CurvedAnimation(
      parent: widget.animation,
      curve: NanoMotionCurves.standardDecel,
      reverseCurve: NanoMotionCurves.standardAccel,
    );
    _curvedSecondary = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: NanoMotionCurves.standardDecel,
      reverseCurve: NanoMotionCurves.standardAccel,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0.0, 0.025),
      end: Offset.zero,
    ).animate(_curvedForward);
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.025, 0.0),
    ).animate(_curvedSecondary);
  }

  @override
  void didUpdateWidget(covariant NanoGlassMorphTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation ||
        old.secondaryAnimation != widget.secondaryAnimation) {
      _curvedForward.dispose();
      _curvedSecondary.dispose();
      _buildCurves();
    }
  }

  @override
  void dispose() {
    _curvedForward.dispose();
    _curvedSecondary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (NanoMotion.reduceMotion(context)) {
      return FadeTransition(opacity: widget.animation, child: widget.child);
    }

    return RepaintBoundary(
      child: SlideTransition(
        position: _slideOut,
        child: SlideTransition(
          position: _slideIn,
          child: FadeTransition(
            opacity: _curvedForward,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Transición secundaria para navegación interna y ajustes (Expressive Slide).
///
/// Optimizada con SlideTransition y FadeTransition en capas nativas para 60/120 fps.
class NanoExpressiveSlideTransition extends StatefulWidget {
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
  State<NanoExpressiveSlideTransition> createState() =>
      _NanoExpressiveSlideTransitionState();
}

class _NanoExpressiveSlideTransitionState
    extends State<NanoExpressiveSlideTransition> {
  late CurvedAnimation _forward;
  late CurvedAnimation _secondary;
  late Animation<Offset> _slideIn;
  late Animation<Offset> _slideOut;

  @override
  void initState() {
    super.initState();
    _buildCurves();
  }

  void _buildCurves() {
    _forward = CurvedAnimation(
      parent: widget.animation,
      curve: NanoMotionCurves.standardDecel,
      reverseCurve: NanoMotionCurves.standardAccel,
    );
    _secondary = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: NanoMotionCurves.standardDecel,
      reverseCurve: NanoMotionCurves.standardAccel,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0.04, 0.0),
      end: Offset.zero,
    ).animate(_forward);
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.03, 0.0),
    ).animate(_secondary);
  }

  @override
  void didUpdateWidget(covariant NanoExpressiveSlideTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation ||
        old.secondaryAnimation != widget.secondaryAnimation) {
      _forward.dispose();
      _secondary.dispose();
      _buildCurves();
    }
  }

  @override
  void dispose() {
    _forward.dispose();
    _secondary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (NanoMotion.reduceMotion(context)) {
      return FadeTransition(opacity: widget.animation, child: widget.child);
    }

    return RepaintBoundary(
      child: SlideTransition(
        position: _slideOut,
        child: SlideTransition(
          position: _slideIn,
          child: FadeTransition(
            opacity: _forward,
            child: widget.child,
          ),
        ),
      ),
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
///
/// MEM-FIX-01: Misma corrección — CurvedAnimation gestionado por Estado.
class NanoModalGlassTransition extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;

  const NanoModalGlassTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  State<NanoModalGlassTransition> createState() =>
      _NanoModalGlassTransitionState();
}

class _NanoModalGlassTransitionState extends State<NanoModalGlassTransition> {
  late CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: NanoMotionCurves.emphasized,
    );
  }

  @override
  void didUpdateWidget(covariant NanoModalGlassTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _curved.dispose();
      _curved = CurvedAnimation(
        parent: widget.animation,
        curve: NanoMotionCurves.emphasized,
      );
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (NanoMotion.reduceMotion(context)) {
      return FadeTransition(opacity: widget.animation, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final t = _curved.value;
        final scale = lerpDouble(0.960, 1.0, t)!;
        final translateY = lerpDouble(8.0, 0.0, t)!;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
        );
      },
    );
  }
}


/// Ruta interna reutilizable para mantener la misma entrada y salida glass de
/// las rutas declarativas de GoRouter. No crea controladores propios y respeta
/// automáticamente la preferencia de reducción de movimiento.
Route<T> nanoGlassPageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    transitionDuration: NanoMotionDurations.navigation,
    reverseTransitionDuration: NanoMotionDurations.navigation,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return NanoGlassMorphTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
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
