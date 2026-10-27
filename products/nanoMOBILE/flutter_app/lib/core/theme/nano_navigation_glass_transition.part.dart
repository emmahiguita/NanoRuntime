part of 'nano_transitions.dart';

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
          child: FadeTransition(opacity: _curvedForward, child: widget.child),
        ),
      ),
    );
  }
}
