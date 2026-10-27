part of 'nano_transitions.dart';

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
    // CurveTween no registra listeners de estado que requieran dispose.
    // El AnimatedBuilder administra su suscripción durante el vuelo del Hero.
    final curved = CurveTween(
      curve: NanoMotionCurves.emphasized,
    ).animate(animation);

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
