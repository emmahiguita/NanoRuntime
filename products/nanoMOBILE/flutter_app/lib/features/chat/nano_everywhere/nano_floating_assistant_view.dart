part of 'nano_floating_assistant.dart';

/// Layout reads policy but does not own animation clocks.
extension _NanoFloatingAssistantView on _NanoFloatingAssistantState {
  /// Keeps expansion geometry and curves; snap ticks apply their position directly.
  Widget buildView(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final window = MediaQuery.sizeOf(context);
    final reduce = !motionEnabled;

    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : window.width;
        final h = box.maxHeight.isFinite ? box.maxHeight : window.height;
        final isLandscape = w > h;
        final orbSize = isLandscape ? 62.0 : 76.0;
        final double width = expanded
            ? (isLandscape
                      ? (w * 0.48).clamp(280.0, 410.0)
                      : (w - 24).clamp(0.0, 390.0))
                  .toDouble()
            : orbSize;
        final double height = expanded
            ? (isLandscape
                      ? (h - 20).clamp(190.0, 310.0)
                      : (h - 24).clamp(0.0, 560.0))
                  .toDouble()
            : orbSize;
        final maxX = (w - width - 8).clamp(0.0, w).toDouble();
        final maxY = (h - height - 12).clamp(0.0, h).toDouble();
        final x = position.dx.clamp(maxX < 8 ? maxX : 8.0, maxX).toDouble();
        final y = position.dy.clamp(maxY < 8 ? maxY : 8.0, maxY).toDouble();

        return Stack(
          children: [
            // Toque fuera del panel: contrae por el mismo camino que la X.
            // Es transparente para conservar el cristal aprobado y solo existe
            // con el panel abierto; el orbe compacto no bloquea la pantalla.
            if (expanded)
              Positioned.fill(
                child: Semantics(
                  label: 'Cerrar asistente',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _collapsePanel,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            AnimatedPositioned(
              key: ValueKey(motionEnabled),
              duration: reduce || _dragging || _snapAnimation != null
                  ? Duration.zero
                  : const Duration(milliseconds: 480),
              curve: Curves.easeInOutCubic,
              left: x,
              top: y,
              width: width,
              height: height,
              child: AnimatedOpacity(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                opacity: expanded ? 1.0 : _opacity,
                child: Nano3dFlipTransition(
                  expanded: expanded,
                  duration: const Duration(milliseconds: 480),
                  orbChild: Center(
                    child: SizedBox(
                      width: orbSize,
                      height: orbSize,
                      child: NanoFloatingOrb(
                        size: orbSize,
                        activity: widget.controller.activity,
                        onTap: () {
                          _wakeUp();
                          setState(() => expanded = true);
                        },
                        onDismiss: _dismissAssistant,
                        onPanStart: (_) {
                          _snapController.stop();
                          _wakeUp();
                          setState(() => _dragging = true);
                        },
                        onPanCancel: () => setState(() => _dragging = false),
                        onPanUpdate: (d) => setState(() {
                          position = Offset(
                            (position.dx + d.delta.dx).clamp(0.0, maxX),
                            (position.dy + d.delta.dy).clamp(0.0, maxY),
                          );
                        }),
                        onPanEnd: (_) => _handlePanEnd(w, maxX, maxY, orbSize),
                      ),
                    ),
                  ),
                  panelChild: NanoAssistantPanel(
                    controller: widget.controller,
                    input: input,
                    audioLevel: widget.audioLevel,
                    onVoice: widget.onVoice,
                    onSpeak: widget.onSpeak,
                    onCollapse: _collapsePanel,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Contrae el panel a orbe: libera la voz propia y reinicia el reposo.
  /// Compartido por la X y el toque exterior; no cancela la consulta en curso
  /// ni borra el borrador, que vive en el controlador de entrada del estado.
  void _collapsePanel() {
    widget.onStopVoice?.call();
    setState(() => expanded = false);
    _wakeUp();
  }
}
