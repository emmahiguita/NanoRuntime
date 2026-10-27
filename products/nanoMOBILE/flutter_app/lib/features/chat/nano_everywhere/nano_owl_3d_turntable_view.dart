part of 'nano_owl_3d_turntable.dart';

/// Dibujo sin relojes propios; el State controla visibilidad y vida útil.
extension _NanoOwl3dTurntableStateView on _NanoOwl3dTurntableState {
  /// Keeps the original drift transform while suppressing rotation when disabled.
  Widget buildView(BuildContext context) {
    final s = widget.size;

    return AnimatedBuilder(
      animation: _ambientController,
      child: NanoOwlAlive(size: s - 12, activity: widget.activity),
      builder: (context, owl) {
        // Deriva ambiental sutil cuando no se está arrastrando
        final ambientYaw = _isDragging || !motionEnabled
            ? 0.0
            : math.sin(_ambientController.value * 2 * math.pi) * 0.06;
        final ambientPitch = _isDragging || !motionEnabled
            ? 0.0
            : math.cos(_ambientController.value * 2 * math.pi) * 0.04;

        final currentYaw = _yaw + ambientYaw;
        final currentPitch = _pitch + ambientPitch;

        // Matriz de proyección 3D con perspectiva cónica real
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0018) // Profundidad focal de perspectiva
          ..rotateX(currentPitch)
          ..rotateY(currentYaw);

        return GestureDetector(
          onTap: widget.onTap,
          onHorizontalDragCancel: widget.interactive && motionEnabled
              ? () {
                  _isDragging = false;
                  _springBackToCenter();
                }
              : null,
          onHorizontalDragStart: widget.interactive && motionEnabled
              ? _onPanStart
              : null,
          onHorizontalDragUpdate: widget.interactive && motionEnabled
              ? _onPanUpdate
              : null,
          onHorizontalDragEnd: widget.interactive && motionEnabled
              ? _onPanEnd
              : null,
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: SizedBox(
              width: s,
              height: s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Sombra de oclusión 3D que se desplaza según el giro
                  Transform.translate(
                    offset: Offset(-currentYaw * 6, 8 + currentPitch * 5),
                    child: Container(
                      width: s * 0.68,
                      height: s * 0.18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.40),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Personaje vivo con sprites orgánicos
                  owl!,

                  // 3. Destello de luz especular dinámica que sigue la rotación 3D
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(
                              math.cos(currentYaw) * 0.75,
                              -0.70 + math.sin(currentPitch) * 0.40,
                            ),
                            radius: 0.70,
                            colors: [
                              Colors.white.withValues(alpha: 0.35),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
