part of 'nano_transitions.dart';

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
  // El Builder recibe un contexto bajo el Overlay del modal para menús y selección.
  // wrap mantiene el contenido actualizado y libera su entrada con el diálogo.
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : NanoMotionDurations.standard,
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Material(
      type: MaterialType.transparency,
      child: Overlay.wrap(child: Builder(builder: builder)),
    ),
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
