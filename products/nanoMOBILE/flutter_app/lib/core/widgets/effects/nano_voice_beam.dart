// nano_voice_beam.dart — Widget contenedor del efecto VoiceBeam reactivo y haz oscilante.
// QUÉ HACE: Envuelve el contenedor de entrada o asistente y proyecta el resplandor lumínico.
// CÓMO FUNCIONA: Activa su AnimationController solo cuando hay escucha o proceso activo; frena en segundo plano.
// POR QUÉ: Erradica procesos zombi, protege la batería y respeta la reducción de movimiento (< 200 líneas).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'nano_voice_beam_painter.dart';
import 'nano_voice_beam_theme.dart';

class NanoVoiceBeam extends StatefulWidget {
  const NanoVoiceBeam({
    super.key,
    required this.child,
    this.audioLevel,
    this.isListening = false,
    this.isProcessing = false,
    this.palette = NanoVoiceBeamPalette.cyber,
    this.physics = const NanoVoiceBeamPhysics(),
    this.borderRadius = 22.0,
    this.type = NanoVoiceBeamType.input,
  });

  final Widget child;
  final ValueListenable<double>? audioLevel;
  final bool isListening;
  final bool isProcessing;
  final NanoVoiceBeamPalette palette;
  final NanoVoiceBeamPhysics physics;
  final double borderRadius;
  final NanoVoiceBeamType type;

  @override
  State<NanoVoiceBeam> createState() => _NanoVoiceBeamState();
}

class _NanoVoiceBeamState extends State<NanoVoiceBeam>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _isAppForeground = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    WidgetsBinding.instance.addObserver(this);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant NanoVoiceBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isListening != widget.isListening ||
        oldWidget.isProcessing != widget.isProcessing) {
      _syncAnimation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate = _isAppForeground &&
        (widget.isListening || widget.isProcessing);

    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final audioListenable = widget.audioLevel ?? ValueNotifier<double>(0.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (!reduceMotion && (widget.isListening || widget.isProcessing))
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_controller, audioListenable]),
                  builder: (context, _) => CustomPaint(
                    painter: NanoVoiceBeamPainter(
                      phase: _controller.value,
                      audioLevel: audioListenable.value,
                      isListening: widget.isListening,
                      isProcessing: widget.isProcessing,
                      palette: widget.palette,
                      physics: widget.physics,
                      borderRadius: widget.borderRadius,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
