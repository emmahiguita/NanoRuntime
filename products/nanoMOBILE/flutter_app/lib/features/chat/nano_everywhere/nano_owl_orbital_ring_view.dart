part of 'nano_owl_orbital_ring.dart';

/// Dibujo sin relojes propios; el State controla visibilidad y vida útil.
extension _NanoOwlOrbitalRingStateView on _NanoOwlOrbitalRingState {
  Widget buildView(BuildContext context) {
    final ringSize = widget.size;

    return AnimatedBuilder(
      animation: _motion,
      child: widget.child,
      builder: (context, owl) {
        final progress = _motion.value;
        final pulse = _isBusy
            ? math.sin(progress * 2 * math.pi) * 0.15 + 0.85
            : 0.80;

        return SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Sombra óptica y profundidad de cristal
              Container(
                width: ringSize - 4,
                height: ringSize - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.12 * pulse),
                      blurRadius: 12 * pulse,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

              // 2. Halo cáustico rotatorio de alta precisión (Skia / Impeller C++ CustomPainter)
              CustomPaint(
                size: Size(ringSize, ringSize),
                painter: _OrbitalCausticPainter(
                  progress: progress,
                  isBusy: _isBusy,
                ),
              ),

              // Una sola lente obtiene color y transparencia del tema compartido.
              GlassSurface(
                width: ringSize - 5,
                height: ringSize - 5,
                radius: (ringSize - 5) / 2,
                blur: 22,
                interactive: false,
                padding: EdgeInsets.zero,
                depth: 0,
                borderWidth: 1.1,
                child: Stack(
                  children: [
                    // Conserva el reflejo superior original sin otro filtro.
                    Positioned(
                      top: 2,
                      left: (ringSize - 5) * 0.18,
                      right: (ringSize - 5) * 0.18,
                      height: (ringSize - 5) * 0.40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular((ringSize - 5) / 2),
                            bottom: const Radius.elliptical(34, 16),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.52),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Búho vivo central perfectamente integrado
              Center(child: owl),
            ],
          ),
        );
      },
    );
  }
}
