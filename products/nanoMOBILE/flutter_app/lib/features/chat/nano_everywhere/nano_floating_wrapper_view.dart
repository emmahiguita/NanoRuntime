part of 'nano_floating_wrapper.dart';

/// Presentación interna: usa el mismo editor/controlador que la ventana externa.
extension _NanoFloatingWrapperView on _NanoFloatingWrapperState {
  Widget buildView(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: NanoFloatingAssistant(
              inputController: sharedInput,
              controller: controller,
              audioLevel: widget.audioLevel,
              onVoice: widget.onVoice ?? voice.toggle,
              onSpeak: voice.read,
              onStopVoice: voice.stop,
            ),
          ),
        ),
      ],
    );
  }
}
