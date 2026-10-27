part of 'nano_owl_alive.dart';

/// Pinta los fotogramas originales sin AnimatedSwitcher ni fundidos añadidos.
extension _NanoOwlAliveStateView on _NanoOwlAliveState {
  /// Cada tick selecciona el sprite real; mantiene respiración e inclinación.
  Widget buildView(BuildContext context) {
    return Listener(
      onPointerDown: _wakeOnInteraction,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: motion,
          builder: (context, child) {
            final p = animate ? motion.value * 2 * math.pi : 0.0;
            final rise = isFly
                ? math.sin(p) * 4.2
                : (isSleep ? 0.0 : math.sin(p) * 2.6);
            final tilt = widget.activity == NanoActivity.listening
                ? math.sin(p) * .024
                : 0.0;

            return Transform.translate(
              offset: Offset(0, rise),
              // Elegir el sprite en cada tick; como child quedaba congelado.
              child: Transform.rotate(
                angle: tilt,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Image.asset(
                    _currentAsset(),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    cacheWidth:
                        (widget.size * MediaQuery.devicePixelRatioOf(context))
                            .round()
                            .clamp(96, 768),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
