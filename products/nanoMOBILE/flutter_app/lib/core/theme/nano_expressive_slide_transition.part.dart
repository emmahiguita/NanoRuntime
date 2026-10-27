part of 'nano_transitions.dart';

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
          child: FadeTransition(opacity: _forward, child: widget.child),
        ),
      ),
    );
  }
}
